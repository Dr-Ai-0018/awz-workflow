"""Domain errors for Reference Library operations."""

from __future__ import annotations

from typing import Any, Dict, Iterable, List, Optional


class ReferenceLibraryError(RuntimeError):
    """A user-actionable failure with optional transaction recovery context."""

    def __init__(
        self,
        message: str,
        *,
        recovery: Optional[Iterable[str]] = None,
        transaction: Optional[Dict[str, Any]] = None,
    ) -> None:
        super().__init__(message)
        self.recovery: List[str] = [str(item) for item in (recovery or [])]
        self.transaction = transaction
