# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL


from taiga.base.serializers import UUIDB64, BaseModel
from taiga.users.serializers.nested import UserNestedSerializer


class DeleteProjectContent(BaseModel):
    id: UUIDB64
    name: str
    workspace_id: UUIDB64
    deleted_by: UserNestedSerializer
