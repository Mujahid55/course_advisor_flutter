import io
import logging
from typing import List, Optional

import numpy as np
import pdfplumber
import pytesseract
from PIL import Image
from sentence_transformers import SentenceTransformer

from app.config import settings

logger = logging.getLogger("course_advisor.document")

_model: Optional[SentenceTransformer] = None


def get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        logger.info("Loading embedding model '%s'", settings.embedding_model_name)
        _model = SentenceTransformer(settings.embedding_model_name)
    return _model


def extract_text(raw: bytes, filename: str) -> str:
    text = ""
    if filename.lower().endswith(".pdf"):
        try:
            with pdfplumber.open(io.BytesIO(raw)) as pdf:
                for page in pdf.pages:
                    text += page.extract_text() or ""
        except Exception as exc:
            logger.warning("pdfplumber failed: %s", exc)

    # OCR fallback for scanned PDFs or image files
    if not text.strip():
        try:
            image = Image.open(io.BytesIO(raw))
            text = pytesseract.image_to_string(image)
        except Exception as exc:
            logger.warning("OCR fallback failed: %s", exc)

    return text


def chunk_text(text: str) -> List[str]:
    words = text.split()
    size = settings.chunk_size
    return [" ".join(words[i : i + size]) for i in range(0, len(words), size)]


def embed_chunks(chunks: List[str]) -> np.ndarray:
    return np.array(get_model().encode(chunks)).astype("float32")


def embed_query(query: str) -> np.ndarray:
    return np.array(get_model().encode([query])).astype("float32")
