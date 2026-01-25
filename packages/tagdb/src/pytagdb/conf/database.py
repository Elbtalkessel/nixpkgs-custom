import functools

import sqlalchemy as sa
from sqlalchemy import orm

from pytagdb.conf import settings

engine = sa.create_engine(settings.DATABASE_URI, echo=settings.DEBUG)
Session = orm.sessionmaker(bind=engine)

col = functools.partial(orm.mapped_column, nullable=False)


class Model(orm.DeclarativeBase):
    id: orm.Mapped[int] = col(primary_key=True)
