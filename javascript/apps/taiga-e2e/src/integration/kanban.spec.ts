/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { randProductName } from '@ngneat/falso';
import { navigateToKanban } from '../support/helpers/kanban.helper';
import { navigateToProjectInWS } from '../support/helpers/project.helpers';

describe('Kanban', () => {
  beforeEach(() => {
    cy.login();
    cy.visit('/');
    cy.initAxe();
    navigateToProjectInWS(0, 0);
    navigateToKanban();
  });

  it('is a11y', () => {
    cy.tgCheckA11y();
  });

  it('create task', () => {
    const title = randProductName();
    console.log(title);

    cy.getBySel('open-create-task-form').first().click();
    cy.getBySel('task-title').type(title);
    cy.getBySel('task-create').click();

    cy.get('tg-kanban-status')
      .first()
      .within(() => {
        cy.contains(title).should('be.visible');
      });
  });
});
