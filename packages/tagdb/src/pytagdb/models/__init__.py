import sqlalchemy as sa
from sqlalchemy import orm
from pytagdb.conf.database import Model, col


class FileIndex(Model):
    __tablename__ = "pytagdb_tags_fileindex"

    fingerprint: orm.Mapped[str] = col(sa.String(64), index=True)
    name: orm.Mapped[str] = col(sa.String(255), index=True)
    tags: orm.Mapped[list["TagThrough"]] = orm.relationship(back_populates="file")


class Tag(Model):
    __tablename__ = "pytagdb_tags_tag"

    name: orm.Mapped[str] = col(sa.String(255))
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
