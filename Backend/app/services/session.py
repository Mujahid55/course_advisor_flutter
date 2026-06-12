import asyncio
import logging
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

import faiss

from app.config import settings

logger = logging.getLogger("course_advisor.session")


@dataclass
class Session:
    index: faiss.IndexFlatL2
    chunks: List[str]
    history: List[dict] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)
    last_used: float = field(default_factory=time.time)


class SessionStore:
    def __init__(self) -> None:
        self._sessions: Dict[str, Session] = {}
        self._lock = asyncio.Lock()

    @property
    def count(self) -> int:
        return len(self._sessions)

    async def get(self, session_id: str) -> Optional[Session]:
        async with self._lock:
            session = self._sessions.get(session_id)
            if session:
                session.last_used = time.time()
            return session

    async def put(self, session_id: str, session: Session) -> None:
        async with self._lock:
            self._sessions[session_id] = session

    async def delete(self, session_id: str) -> bool:
        async with self._lock:
            return self._sessions.pop(session_id, None) is not None

    async def purge_expired(self) -> int:
        now = time.time()
        async with self._lock:
            expired = [
                sid
                for sid, sess in self._sessions.items()
                if now - sess.last_used > settings.session_ttl_seconds
            ]
            for sid in expired:
                del self._sessions[sid]
        if expired:
            logger.info("Purged %d expired session(s)", len(expired))
        return len(expired)


session_store = SessionStore()
