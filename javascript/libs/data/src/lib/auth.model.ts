/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */
import { User } from './user.model';

export interface Auth {
  token: string;
  refresh: string;
}

export interface LoginInput {
  password: string;
  username: User['username'];
}
