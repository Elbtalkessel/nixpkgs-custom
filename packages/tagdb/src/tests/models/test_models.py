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
