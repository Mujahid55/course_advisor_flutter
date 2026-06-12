import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.db_models import AppUsageStat, User
from app.models.schemas import ChatRequest, ChatResponse, DeleteResponse
from app.services.ai import chat_completion
from app.services.auth import get_current_user
from app.services.document import embed_query
from app.services.session import session_store

logger = logging.getLogger("course_advisor.chat")
router = APIRouter(tags=["session"])

_SYSTEM_PROMPT = """You are CourseAdvisor, a friendly and knowledgeable academic assistant.
You help university students understand their course syllabus and find the best study resources.

Personality:
- Warm, encouraging, and supportive — like a helpful senior student or tutor
- Clear and well-organised in your answers
- Use emojis occasionally (not excessively)
- End with a helpful follow-up suggestion when relevant

Responsibilities:
- Identify the subject and key topics from the syllabus
- Recommend 4–5 high-quality textbooks (prefer Saudi Digital Library sources when relevant)
- Summarise learning objectives and exam topics clearly
- Guide students on what to focus on

Scope rule:
- Answer questions about: courses, syllabus, subjects, topics, objectives, books, references, exams, study tips, academic resources.
- For anything unrelated (weather, sports, politics, etc.) politely decline and redirect.

Format:
- Book recommendations: title, author, one-sentence reason
- Topic summaries: short bullet points
- Keep responses concise — avoid walls of text
- Use line breaks for mobile readability"""


@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(
    session_id: str,
    request: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChatResponse:
    if not session_id.strip():
        raise HTTPException(status_code=400, detail="session_id must not be empty.")

    session = await session_store.get(session_id)
    if session is None:
        raise HTTPException(
            status_code=404,
            detail="No syllabus found for this session. Please upload your course PDF first.",
        )

    query_vec = embed_query(request.message)
    _, indices = session.index.search(query_vec, k=settings.rag_top_k)
    context = "\n".join(
        session.chunks[i] for i in indices[0] if 0 <= i < len(session.chunks)
    )

    user_content = (
        f"SYLLABUS CONTENT:\n{context}\n\n"
        f"STUDENT'S QUESTION:\n{request.message}\n\n"
        "Respond in a helpful, human, and encouraging tone."
    )

    trimmed_history = session.history[-(settings.max_history_turns * 2):]
    messages = (
        [{"role": "system", "content": _SYSTEM_PROMPT}]
        + trimmed_history
        + [{"role": "user", "content": user_content}]
    )

    reply = chat_completion(messages)

    session.history.append({"role": "user", "content": request.message})
    session.history.append({"role": "assistant", "content": reply})

    db.add(AppUsageStat(user_id=current_user.id, action_type="chat_message"))
    await db.commit()

    logger.info("Session %s (user %s): replied (%d chars)", session_id, current_user.id, len(reply))
    return ChatResponse(reply=reply)


@router.delete("/session", response_model=DeleteResponse)
async def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DeleteResponse:
    if not session_id.strip():
        raise HTTPException(status_code=400, detail="session_id must not be empty.")
    deleted = await session_store.delete(session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found.")
    logger.info("Session %s: deleted by user %s", session_id, current_user.id)
    return DeleteResponse(deleted=True)
