# Generated by Django 3.2.12 on 2022-02-10 11:52

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0009_auto_20200615_0811'),
    ]

    operations = [
        migrations.AlterField(
            model_name='historychangenotification',
            name='id',
            field=models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
        migrations.AlterField(
            model_name='notifypolicy',
            name='id',
            field=models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
        migrations.AlterField(
            model_name='watched',
            name='id',
            field=models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
        migrations.AlterField(
            model_name='webnotification',
            name='id',
            field=models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
    ]