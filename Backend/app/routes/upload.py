import logging

import faiss
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.db_models import AppUsageStat, User
from app.models.schemas import ChatResponse
from app.services.auth import get_current_user
from app.services.document import chunk_text, embed_chunks, extract_text
from app.services.session import Session, session_store

logger = logging.getLogger("course_advisor.upload")
router = APIRouter(tags=["session"])

_ALLOWED_EXTENSIONS = (".pdf", ".png", ".jpg", ".jpeg")


@router.post("/upload", response_model=ChatResponse)
async def upload_file(
    session_id: str,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChatResponse:
    if not session_id.strip():
        raise HTTPException(status_code=400, detail="session_id must not be empty.")

    if not (file.filename or "").lower().endswith(_ALLOWED_EXTENSIONS):
        raise HTTPException(
            status_code=415,
            detail="Unsupported file type. Please upload a PDF or image file.",
        )

    raw = await file.read()

    if len(raw) > settings.max_file_bytes:
        limit_mb = settings.max_file_bytes // (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"File exceeds the {limit_mb} MB upload limit.",
        )

    text = extract_text(raw, file.filename or "")
    if not text.strip():
        raise HTTPException(
            status_code=422,
            detail=(
                "Could not extract text from the file. "
                "Please ensure it is a clear, text-based PDF and try again."
            ),
        )

    chunks = chunk_text(text)
    embeddings = embed_chunks(chunks)

    index = faiss.IndexFlatL2(embeddings.shape[1])
    index.add(embeddings)

    await session_store.put(session_id, Session(index=index, chunks=chunks))
    logger.info(
        "Session %s (user %s): indexed %d chunks from '%s'",
        session_id, current_user.id, len(chunks), file.filename,
    )

    db.add(AppUsageStat(user_id=current_user.id, action_type="upload"))
    await db.commit()

    return ChatResponse(
        reply=(
            "✅ Your syllabus has been uploaded and analysed successfully!\n\n"
            "I've gone through the content and I'm ready to help. Here's what I can do:\n\n"
            "📚 Recommend the best textbooks for your course\n"
            "🔍 Summarise key topics and learning objectives\n"
            "💡 Explain any subject area from your syllabus\n\n"
            "What would you like to know first?"
        )
    )
