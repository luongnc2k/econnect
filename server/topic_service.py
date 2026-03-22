import re
import unicodedata
import uuid
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from models.class_ import Class
from models.topic import Topic


def normalize_topic_name(value: str) -> str:
    return " ".join(value.strip().split())


def resolve_class_topic_label(
    cls: Class,
    *,
    topic: Optional[Topic] = None,
) -> str:
    raw_topic = (getattr(cls, "topic", None) or "").strip()
    if raw_topic:
        return raw_topic
    if topic is not None and topic.name.strip():
        return topic.name.strip()
    return ""


def ensure_topic_record(db: Session, topic_name: str) -> Topic:
    normalized_name = normalize_topic_name(topic_name)
    existing = (
        db.query(Topic)
        .filter(func.lower(Topic.name) == normalized_name.lower())
        .order_by(Topic.is_active.desc(), Topic.name.asc())
        .first()
    )
    if existing:
        if not existing.is_active:
            existing.is_active = True
        return existing

    base_slug = _slugify_topic_name(normalized_name)
    slug = base_slug
    counter = 1
    while db.query(Topic.id).filter(Topic.slug == slug).first():
        suffix = f"-{counter}"
        slug = f"{base_slug[: max(1, 100 - len(suffix))]}{suffix}"
        counter += 1

    topic = Topic(
        id=str(uuid.uuid4()),
        name=normalized_name,
        slug=slug,
        description=None,
        icon=None,
        is_active=True,
    )
    db.add(topic)
    db.flush()
    return topic


def _slugify_topic_name(topic_name: str) -> str:
    ascii_name = (
        unicodedata.normalize("NFKD", topic_name)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_name).strip("-")
    return (slug or "topic")[:100]
