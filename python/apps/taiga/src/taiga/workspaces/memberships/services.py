# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

from typing import Final
from uuid import UUID

from taiga.projects.memberships import repositories as projects_memberships_repositories
from taiga.workspaces.memberships import repositories as workspace_memberships_repositories

WS_ROLE_NAME_ADMIN: Final = "admin"
WS_ROLE_NAME_GUEST: Final = "guest"
WS_ROLE_NAME_NONE: Final = "none"


##########################################################
# misc
##########################################################


async def get_workspace_role_name(
    workspace_id: UUID,
    user_id: UUID | None,
) -> str:
    if not user_id:
        return WS_ROLE_NAME_NONE

    ws_membership = await workspace_memberships_repositories.get_workspace_membership(
        filters={"workspace_id": workspace_id, "user_id": user_id},
    )
    if ws_membership:
        return WS_ROLE_NAME_ADMIN

    else:
        pj_membership = await projects_memberships_repositories.exist_project_membership(
            filters={"user_id": user_id, "project__workspace_id": workspace_id}
        )
        if pj_membership:
            return WS_ROLE_NAME_GUEST
        else:
            return WS_ROLE_NAME_NONE