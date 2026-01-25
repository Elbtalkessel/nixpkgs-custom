from pathlib import Path

from sqlalchemy import orm

from pytagdb.models import Tag, TagThrough, FileIndex


def test_create_a_tag(db_session: orm.Session) -> None:
    """
    A tag can be inserted.
    """
    tag = Tag(name="foo")
    with db_session.begin():
        db_session.add(tag)
    assert tag.id is not None


def test_database_is_empty(db_session: orm.Session) -> None:
    """
    Pytest setup sanity check to run after a first test inserted
    into database something.
    Each test must be isolated and any data rolled back.
    """

    assert db_session.query(Tag).count() == 0


def test_create_a_file(db_session: orm.Session) -> None:
    """
    A file can be inserted.
    """
    file = FileIndex(fingerprint="abc", name="foo.txt")
    with db_session.begin():
        db_session.add(file)
    assert file.id is not None


def test_a_file_can_be_associated_with_a_tag(db_session: orm.Session) -> None:
    """
    A file can be tagged.
    """
    file = FileIndex(fingerprint="abc", name="foo.txt")
    tag = Tag(name="text")
    thru = TagThrough()
    with db_session.begin():
        db_session.add_all((file, tag))
    with db_session.begin():
        thru.tag_id = tag.id
        thru.fileindex_id = file.id
        db_session.add(thru)

    file = db_session.query(FileIndex).first()
    assert file is not None
    assert file.tags[0].tag.name == "text"

    tag = db_session.query(Tag).first()
    assert tag is not None
    assert tag.files[0].file.name == "foo.txt"


def test_create_a_file_from_path(tmp_path: Path) -> None:
    """
    Creates a file record saving its hashsum and name.
    """
    f = tmp_path / "README.md"
    f.touch()
    index = FileIndex.new(f)
    assert (
        index.fingerprint
        == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
    assert index.name == "README.md"


def test_can_tag_a_file(tmp_path: Path, db_session: orm.Session) -> None:
    """
    Have an utility method for easy file tagging.
    """
    f = tmp_path / "README.md"
    f.touch()
    index = FileIndex.new(f)
    with db_session.begin():
        db_session.add(index)
    index.tagit(["text", "document", "markdown"])
    exists = db_session.query(TagThrough).where(TagThrough.fileindex_id == index.id)
    tags = db_session.query(Tag).where(Tag.id.in_([t.id for t in exists]))
    assert set(t.name for t in tags) == {"text", "document", "markdown"}
