import typing

import pytest
import sqlalchemy as sa
from sqlalchemy.engine import NestedTransaction
from sqlalchemy import orm

from pytagdb.conf.database import Session, Model, engine


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Model.metadata.create_all(engine)


@pytest.fixture(scope="function")
def db_session():
    # See https://docs.sqlalchemy.org/en/20/orm/session_transaction.html#joining-a-session-into-an-external-transaction-such-as-for-test-suites
    # join_transaction_mode="create_savepoint" gives error

    connection = engine.connect()
    transaction = connection.begin()

    # Create a new session
    session = Session(bind=connection)

    try:
        yield session
    finally:
        # rollback - everything that happened with the
        # Session above (including calls to commit())
        # is rolled back.
        session.close()
        transaction.rollback()
        connection.close()
