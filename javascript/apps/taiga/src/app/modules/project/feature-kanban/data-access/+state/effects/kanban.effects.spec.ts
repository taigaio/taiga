/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { createServiceFactory, SpectatorService } from '@ngneat/spectator/jest';
import { provideMockActions } from '@ngrx/effects/testing';
import { Action } from '@ngrx/store';
import { ProjectApiService } from '@taiga/api';
import { AppService } from '~/app/services/app.service';
import { Observable } from 'rxjs';

import { KanbanEffects } from './kanban.effects';
import { KanbanActions, KanbanApiActions } from '../actions/kanban.actions';
import { cold, hot } from 'jest-marbles';
import {
  ProjectMockFactory,
  TaskMockFactory,
  UserMockFactory,
  WorkflowMockFactory,
} from '@taiga/data';

import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { selectUser } from '~/app/modules/auth/data-access/+state/selectors/auth.selectors';
import { selectCurrentProject } from '~/app/modules/project/data-access/+state/selectors/project.selectors';
import { fetchProject } from '~/app/modules/project/data-access/+state/actions/project.actions';
describe('ProjectEffects', () => {
  let actions$: Observable<Action>;
  let spectator: SpectatorService<KanbanEffects>;
  let store: MockStore;

  const createService = createServiceFactory({
    service: KanbanEffects,
    providers: [
      provideMockActions(() => actions$),
      provideMockStore({ initialState: {} }),
    ],
    mocks: [ProjectApiService, AppService],
  });

  beforeEach(() => {
    spectator = createService();
    store = spectator.inject(MockStore);
    const user = UserMockFactory();
    store.overrideSelector(selectUser, user);
  });

  it('init kanban', () => {
    const project = ProjectMockFactory();
    const projectApiService = spectator.inject(ProjectApiService);
    const effects = spectator.inject(KanbanEffects);
    const workflows = [WorkflowMockFactory(3)];

    store.overrideSelector(selectCurrentProject, project);

    projectApiService.getWorkflows.mockReturnValue(
      cold('-b|', { b: workflows })
    );

    actions$ = hot('-a', { a: KanbanActions.initKanban() });

    const expected = cold('--a', {
      a: KanbanApiActions.fetchWorkflowsSuccess({ workflows }),
    });

    expect(effects.loadKanbanWorkflows$).toBeObservable(expected);
  });

  it('load tasks', () => {
    const projectApiService = spectator.inject(ProjectApiService);
    const effects = spectator.inject(KanbanEffects);
    const tasks = [TaskMockFactory()];

    projectApiService.getTasks.mockReturnValue(cold('-b|', { b: tasks }));

    actions$ = hot('-a', { a: KanbanActions.initKanban() });

    const expected = cold('--a', {
      a: KanbanApiActions.fetchTasksSuccess({ tasks }),
    });

    expect(effects.loadKanbanTasks$).toBeObservable(expected);
  });

  it('create task', () => {
    const projectApiService = spectator.inject(ProjectApiService);
    const effects = spectator.inject(KanbanEffects);
    const task = TaskMockFactory();

    projectApiService.createTask.mockReturnValue(cold('-b|', { b: task }));

    actions$ = hot('-a', {
      a: KanbanActions.createTask({ task, workflow: 'main' }),
    });

    const expected = cold('--a', {
      a: KanbanApiActions.createTasksSuccess({ task }),
    });

    expect(effects.createTask$).toBeObservable(expected);
  });

  it('create task error', () => {
    const projectApiService = spectator.inject(ProjectApiService);
    const effects = spectator.inject(KanbanEffects);
    const appService = spectator.inject(AppService);
    const task = TaskMockFactory();

    const error = {
      status: 401,
    };

    projectApiService.createTask.mockReturnValue(cold('-#|', {}, error));

    actions$ = hot('-a', {
      a: KanbanActions.createTask({ task, workflow: 'main' }),
    });

    const expected = cold('--a', {
      a: KanbanApiActions.createTasksError({ status: error.status, task }),
    });

    expect(effects.createTask$).toBeObservable(expected);

    expect(effects.createTask$).toSatisfyOnFlush(() => {
      expect(appService.toastNotification).not.toHaveBeenCalled();
    });
  });

  it('create task error notification', () => {
    const project = ProjectMockFactory();
    const effects = spectator.inject(KanbanEffects);
    const appService = spectator.inject(AppService);
    const task = TaskMockFactory();

    store.overrideSelector(selectCurrentProject, project);

    actions$ = hot('-a', {
      a: KanbanApiActions.createTasksError({ status: 401, task }),
    });

    const expected = cold('-a', {
      a: fetchProject({ slug: project.slug }),
    });

    expect(effects.createTaskError$).toBeObservable(expected);

    expect(effects.createTaskError$).toSatisfyOnFlush(() => {
      expect(appService.toastNotification).toHaveBeenCalled();
    });
  });
});
