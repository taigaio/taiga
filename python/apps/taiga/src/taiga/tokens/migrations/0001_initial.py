# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

# Generated by Django 4.1.3 on 2023-06-12 18:57

import django.db.models.deletion
import taiga.base.db.models
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("contenttypes", "0002_remove_content_type_name"),
    ]

    operations = [
        migrations.CreateModel(
            name="OutstandingToken",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        blank=True,
                        default=taiga.base.db.models.uuid_generator,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("object_id", models.UUIDField(blank=True, null=True)),
                ("jti", models.CharField(max_length=255, unique=True)),
                ("token_type", models.TextField()),
                ("token", models.TextField()),
                ("created_at", models.DateTimeField(blank=True, null=True)),
                ("expires_at", models.DateTimeField()),
                (
                    "content_type",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        to="contenttypes.contenttype",
                    ),
                ),
            ],
            options={
                "verbose_name": "outstanding token",
                "verbose_name_plural": "outstanding tokens",
                "ordering": ("content_type", "object_id", "token_type"),
            },
        ),
        migrations.CreateModel(
            name="DenylistedToken",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        blank=True,
                        default=taiga.base.db.models.uuid_generator,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("denylisted_at", models.DateTimeField(auto_now_add=True)),
                (
                    "token",
                    models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, to="tokens.outstandingtoken"),
                ),
            ],
            options={
                "verbose_name": "denylisted token",
                "verbose_name_plural": "denylisted tokens",
            },
        ),
        migrations.AddIndex(
            model_name="outstandingtoken",
            index=models.Index(
                fields=["content_type", "object_id", "token_type"], name="tokens_outs_content_1b2775_idx"
            ),
        ),
        migrations.AddIndex(
            model_name="outstandingtoken",
            index=models.Index(fields=["jti"], name="tokens_outs_jti_766f39_idx"),
        ),
        migrations.AddIndex(
            model_name="outstandingtoken",
            index=models.Index(fields=["expires_at"], name="tokens_outs_expires_ce645d_idx"),
        ),
        migrations.AddIndex(
            model_name="denylistedtoken",
            index=models.Index(fields=["token"], name="tokens_deny_token_i_25cc28_idx"),
        ),
    ]
