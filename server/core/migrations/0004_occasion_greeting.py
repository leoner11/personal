from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0003_task'),
    ]

    operations = [
        migrations.AddField(
            model_name='occasion',
            name='greeting',
            field=models.TextField(blank=True, default=''),
        ),
    ]
