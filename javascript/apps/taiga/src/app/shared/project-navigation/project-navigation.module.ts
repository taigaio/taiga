/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { A11yModule } from '@angular/cdk/a11y';
import { CommonModule } from '@angular/common';
import { NgModule } from '@angular/core';
import { RouterModule } from '@angular/router';
import { TranslocoModule } from '@ngneat/transloco';
import { TuiButtonModule, TuiSvgModule } from '@taiga-ui/core';
import { ProjectNavigationComponent } from './project-navigation.component';

@NgModule({
  imports: [
    CommonModule,
    TuiButtonModule,
    TuiSvgModule,
    TranslocoModule,
    A11yModule,
    RouterModule
  ],
  declarations: [
    ProjectNavigationComponent,
  ],
  providers: [],
  exports: [
    ProjectNavigationComponent,
  ]
})
export class ProjectNavigationModule {}
