import typing

import pytest
import sqlalchemy as sa
from sqlalchemy.engine import NestedTransaction
from sqlalchemy import orm

from pytagdb.conf.database import Session, Model, engine


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Model.metadata.create_all(engine)


@pytest.fixture(scope="module", autouse=True)
def db_connection() -> typing.Generator[sa.Connection]:
    conn = engine.connect()
    try:
        yield conn
    finally:
        conn.close()


@pytest.fixture(scope="function", autouse=True)
def db_transaction(db_connection: sa.Connection) -> typing.Generator[NestedTransaction]:
    trans = db_connection.begin_nested()
    try:
        yield trans
    finally:
        trans.rollback()


@pytest.fixture(scope="function")
def db_session(db_connection: sa.Connection) -> typing.Generator[orm.Session]:
    sess = Session(bind=db_connection, join_transaction_mode="create_savepoint")
    try:
        yield sess
    finally:
        sess.close()
