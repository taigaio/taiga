# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

from unittest.mock import patch

import pytest
from taiga.projects.memberships import services
from taiga.projects.memberships.services import exceptions as ex
from tests.utils import factories as f

pytestmark = pytest.mark.django_db


#######################################################
# get_paginated_project_memberships
#######################################################


async def test_get_paginated_project_memberships():
    project = f.build_project()
    with patch(
        "taiga.projects.memberships.services.memberships_repositories", autospec=True
    ) as fake_membership_repository:
        await services.get_paginated_project_memberships(project=project, offset=0, limit=10)
        fake_membership_repository.get_project_memberships.assert_awaited_once()
        fake_membership_repository.get_total_project_memberships.assert_awaited_once()


#######################################################
# update_project_membership
#######################################################


async def test_update_project_membership_role_non_existing_role():
    project = f.build_project()
    user = f.build_user()
    general_role = f.build_project_role(project=project, is_admin=False)
    membership = f.build_project_membership(user=user, project=project, role=general_role)
    non_existing_role_slug = "non_existing_role_slug"
    with (
        patch("taiga.projects.memberships.services.roles_repositories", autospec=True) as fake_role_repository,
        patch(
            "taiga.projects.memberships.services.memberships_repositories", autospec=True
        ) as fake_membership_repository,
        patch("taiga.projects.memberships.services.memberships_events", autospec=True) as fake_membership_events,
        pytest.raises(ex.NonExistingRoleError),
    ):
        fake_role_repository.get_project_role.return_value = None

        await services.update_project_membership(membership=membership, role_slug=non_existing_role_slug)
        fake_role_repository.get_project_role.assert_awaited_once_with(project=project, slug=non_existing_role_slug)
        fake_membership_repository.update_project_membership.assert_not_awaited()
        fake_membership_events.emit_event_when_project_membership_is_updated.assert_not_awaited()


async def test_update_project_membership_role_only_one_admin():
    project = f.build_project()
    admin_role = f.build_project_role(project=project, is_admin=True)
    membership = f.build_project_membership(user=project.owner, project=project, role=admin_role)
    general_role = f.build_project_role(project=project, is_admin=False)
    with (
        patch("taiga.projects.memberships.services.roles_repositories", autospec=True) as fake_role_repository,
        patch(
            "taiga.projects.memberships.services.memberships_repositories", autospec=True
        ) as fake_membership_repository,
        patch("taiga.projects.memberships.services.memberships_events", autospec=True) as fake_membership_events,
        pytest.raises(ex.MembershipIsTheOnlyAdminError),
    ):
        fake_role_repository.get_project_role.return_value = general_role
        fake_membership_repository.get_num_members_by_role_id.return_value = 1

        await services.update_project_membership(membership=membership, role_slug=general_role.slug)
        fake_role_repository.get_project_role.assert_awaited_once_with(project=project, slug=general_role.slug)
        fake_membership_repository.get_num_members_by_role_id.assert_awaited_once_with(role_id=admin_role.id)
        fake_membership_repository.update_project_membership.assert_not_awaited()
        fake_membership_events.emit_event_when_project_membership_is_updated.assert_not_awaited()


async def test_update_project_membership_role_ok():
    project = f.build_project()
    user = f.build_user()
    general_role = f.build_project_role(project=project, is_admin=False)
    membership = f.build_project_membership(user=user, project=project, role=general_role)
    admin_role = f.build_project_role(project=project, is_admin=True)
    with (
        patch("taiga.projects.memberships.services.roles_repositories", autospec=True) as fake_role_repository,
        patch(
            "taiga.projects.memberships.services.memberships_repositories", autospec=True
        ) as fake_membership_repository,
        patch("taiga.projects.memberships.services.memberships_events", autospec=True) as fake_membership_events,
    ):
        fake_role_repository.get_project_role.return_value = admin_role

        updated_membership = await services.update_project_membership(membership=membership, role_slug=admin_role.slug)
        fake_role_repository.get_project_role.assert_awaited_once_with(project=project, slug=admin_role.slug)
        fake_membership_repository.get_num_members_by_role_id.assert_not_awaited()
        fake_membership_repository.update_project_membership.assert_awaited_once_with(
            membership=membership, role=admin_role
        )
        fake_membership_events.emit_event_when_project_membership_is_updated.assert_awaited_once_with(
            membership=updated_membership
        )