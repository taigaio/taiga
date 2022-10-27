/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { DragDropModule } from '@angular/cdk/drag-drop';
import { CommonModule } from '@angular/common';
import { NgModule } from '@angular/core';
import { TranslocoModule } from '@ngneat/transloco';
import { TuiButtonModule, TuiSvgModule } from '@taiga-ui/core';
import { StoryDetailSkeletonComponent } from '../story-detail-skeleton/story-detail-skeleton.component';
import { KanbanStoryDetailComponent } from '../story-detail/kanban-story-detail.component';
import { ProjectFeatureStoryWrapperSideViewComponent } from './project-feature-story-wrapper-side-view.component';

@NgModule({
  imports: [
    CommonModule,
    TuiButtonModule,
    TuiSvgModule,
    TranslocoModule,
    KanbanStoryDetailComponent,
    DragDropModule,
    StoryDetailSkeletonComponent,
  ],
  declarations: [ProjectFeatureStoryWrapperSideViewComponent],
  providers: [],
  exports: [ProjectFeatureStoryWrapperSideViewComponent],
})
export class ProjectFeatureStoryWrapperSideViewModule {}
