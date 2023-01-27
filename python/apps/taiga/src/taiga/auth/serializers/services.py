# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL


from taiga.auth.serializers import AccessTokenWithRefreshSerializer
from taiga.auth.tokens import RefreshToken


def serialize_access_refresh_token(
    refresh_token: RefreshToken,
) -> AccessTokenWithRefreshSerializer:
    return AccessTokenWithRefreshSerializer(token=str(refresh_token.access_token), refresh=str(refresh_token))