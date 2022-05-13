# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

from typing import Any

from taiga.base.api.permissions import PermissionComponent
from taiga.invitations import services as invitations_services
from taiga.permissions import services as permissions_services
from taiga.users.models import User


class IsProjectInvitationRecipient(PermissionComponent):
    async def is_authorized(self, user: User, obj: Any = None) -> bool:
        if not obj or user.is_anonymous or not user.is_active:
            return False

        return invitations_services.is_project_invitation_for_this_user(obj, user)


class HasPendingProjectInvitation(PermissionComponent):
    async def is_authorized(self, user: User, obj: Any = None) -> bool:
        if not obj or user.is_anonymous or not user.is_active:
            return False

        project = await permissions_services._get_object_project(obj)
        return await invitations_services.has_pending_project_invitation_for_user(project=project, user=user)