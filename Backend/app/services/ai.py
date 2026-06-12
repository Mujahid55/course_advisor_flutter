import logging
from typing import List

from fastapi import HTTPException
from openai import APIError, OpenAI

from app.config import settings

logger = logging.getLogger("course_advisor.ai")

openai_client = OpenAI(api_key=settings.openai_api_key)


def chat_completion(messages: List[dict]) -> str:
    try:
        completion = openai_client.chat.completions.create(
            model=settings.openai_model,
            messages=messages,
            temperature=settings.temperature,
            max_tokens=settings.max_tokens,
        )
        return completion.choices[0].message.content or ""
    except APIError as exc:
        logger.error("OpenAI API error: %s", exc)
        raise HTTPException(
            status_code=502,
            detail="The AI service is temporarily unavailable. Please try again shortly.",
        )
