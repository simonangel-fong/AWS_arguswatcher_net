# Generated by Django 4.2.8 on 2024-01-03 19:25

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Blog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=64)),
                ('content', models.TextField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
                'indexes': [models.Index(fields=['author'], name='AppBlog_blo_author__2a3df2_idx'), models.Index(fields=['title'], name='AppBlog_blo_title_2638e2_idx'), models.Index(fields=['created_at'], name='AppBlog_blo_created_5b780e_idx'), models.Index(fields=['updated_at'], name='AppBlog_blo_updated_e2add1_idx')],
            },
        ),
    ]
