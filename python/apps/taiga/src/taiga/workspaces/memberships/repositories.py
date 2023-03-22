# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

from typing import Literal, TypedDict
from uuid import UUID

from asgiref.sync import sync_to_async
from taiga.base.db.models import QuerySet
from taiga.users.models import User
from taiga.workspaces.memberships.models import WorkspaceMembership
from taiga.workspaces.workspaces.models import Workspace

##########################################################
# filters and querysets
##########################################################


DEFAULT_QUERYSET = WorkspaceMembership.objects.all()


class WorkspaceMembershipFilters(TypedDict, total=False):
    workspace_id: UUID
    user_id: UUID


def _apply_filters_to_queryset(
    qs: QuerySet[WorkspaceMembership],
    filters: WorkspaceMembershipFilters = {},
) -> QuerySet[WorkspaceMembership]:
    return qs.filter(**filters)


WorkspaceMembershipSelectRelated = list[
    Literal[
        "user",
        "workspace",
    ]
]


def _apply_select_related_to_queryset(
    qs: QuerySet[WorkspaceMembership],
    select_related: WorkspaceMembershipSelectRelated,
) -> QuerySet[WorkspaceMembership]:
    return qs.select_related(*select_related)


WorkspaceMembershipOrderBy = list[
    Literal[
        "full_name",
    ]
]


def _apply_order_by_to_queryset(
    qs: QuerySet[WorkspaceMembership],
    order_by: WorkspaceMembershipOrderBy,
) -> QuerySet[WorkspaceMembership]:
    order_by_data = []

    for key in order_by:
        if key == "full_name":
            order_by_data.append("user__full_name")
        else:
            order_by_data.append(key)

    return qs.order_by(*order_by_data)


##########################################################
# create workspace membership
##########################################################


@sync_to_async
def create_workspace_membership(user: User, workspace: Workspace) -> WorkspaceMembership:
    return WorkspaceMembership.objects.create(user=user, workspace=workspace)


##########################################################
# list project memberships
##########################################################


@sync_to_async
def list_workspace_memberships(
    filters: WorkspaceMembershipFilters = {},
    select_related: WorkspaceMembershipSelectRelated = [],
    order_by: WorkspaceMembershipOrderBy = ["full_name"],
    offset: int | None = None,
    limit: int | None = None,
) -> list[WorkspaceMembership]:
    qs = _apply_filters_to_queryset(qs=DEFAULT_QUERYSET, filters=filters)
    qs = _apply_select_related_to_queryset(qs=qs, select_related=select_related)
    qs = _apply_order_by_to_queryset(order_by=order_by, qs=qs)

    if limit is not None and offset is not None:
        limit += offset

    return list(qs[offset:limit])


##########################################################
# get workspace membership
##########################################################


@sync_to_async
def get_workspace_membership(
    filters: WorkspaceMembershipFilters = {},
    select_related: WorkspaceMembershipSelectRelated = [],
) -> WorkspaceMembership | None:
    qs = _apply_filters_to_queryset(filters=filters, qs=DEFAULT_QUERYSET)
    qs = _apply_select_related_to_queryset(qs=qs, select_related=select_related)
    try:
        return qs.get()
    except WorkspaceMembership.DoesNotExist:
        return None


##########################################################
# misc
##########################################################


@sync_to_async
def get_total_workspace_memberships(filters: WorkspaceMembershipFilters = {}) -> int:
    qs = _apply_filters_to_queryset(qs=DEFAULT_QUERYSET, filters=filters)
    return qs.count()
