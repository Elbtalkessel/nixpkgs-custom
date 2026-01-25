from pathlib import Path
import hashlib
import typing

import sqlalchemy as sa
from sqlalchemy import orm

from pytagdb.conf.database import Model, col, Session


class FileIndex(Model):
    __tablename__ = "pytagdb_tags_fileindex"

    fingerprint: orm.Mapped[str] = col(sa.String(64), index=True)
    name: orm.Mapped[str] = col(sa.String(255), index=True)
    tags: orm.Mapped[list["TagThrough"]] = orm.relationship(back_populates="file")

    @classmethod
    def new(cls, filepath: Path):
        m = hashlib.sha256()
        m.update(filepath.read_bytes())
        m.digest()
        return cls(fingerprint=m.hexdigest(), name=filepath.name)

    def tagit(self, tags: typing.Collection[str]):
        session = Session()
        with session.begin():
            exists = session.query(Tag).where(Tag.name.in_(tags))
            unique_tags = set(tags) - set(t.name for t in exists)
            instances = [Tag(name=t) for t in unique_tags]
            session.add_all(instances)
        with session.begin():
            session.add_all(
                TagThrough(tag_id=t.id, fileindex_id=self.id) for t in instances
            )


class Tag(Model):
    __tablename__ = "pytagdb_tags_tag"

    name: orm.Mapped[str] = col(sa.String(255), unique=True)
    files: orm.Mapped[list["TagThrough"]] = orm.relationship(back_populates="tag")


class TagThrough(Model):
    __tablename__ = "pytagdb_tags_tags"

    tag_id: orm.Mapped[int] = col(
        sa.ForeignKey(f"{Tag.__tablename__}.id"),
        index=True,
    )
    fileindex_id: orm.Mapped[int] = col(
        sa.ForeignKey(f"{FileIndex.__tablename__}.id"),
        index=True,
    )
    tag: orm.Mapped[Tag] = orm.relationship(back_populates="files")
    file: orm.Mapped[FileIndex] = orm.relationship(back_populates="tags")
