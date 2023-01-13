# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

import pytest
from taiga.stories.assignments import repositories
from tests.utils import factories as f

pytestmark = pytest.mark.django_db


##########################################################
# create_story_assignment
##########################################################


async def test_create_story_assignment_ok() -> None:
    user = await f.create_user()
    story = await f.create_story()

    story_assignment, created = await repositories.create_story_assignment(story=story, user=user)

    assert story_assignment.user == user
    assert story_assignment.story == story


##########################################################
# get_story_assignment
##########################################################


async def test_get_story_assignment() -> None:
    story_assignment = await f.create_story_assignment()
    story_assignment_test = await repositories.get_story_assignment(
        filters={"story_id": story_assignment.story.id, "username": story_assignment.user.username},
        select_related=["story", "user", "story__project"],
    )
    assert story_assignment.user.username == story_assignment_test.user.username
    assert story_assignment.story.id == story_assignment_test.story.id


##########################################################
# delete_story_assignment
##########################################################


async def test_delete_story_assignment() -> None:
    story_assignment = await f.create_story_assignment()
    story_assignment_deleted = await repositories.delete_story_assignment(
        filters={"story_id": story_assignment.story.id, "username": story_assignment.user.username},
    )
    assert story_assignment_deleted == 1
