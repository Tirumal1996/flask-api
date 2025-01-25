FROM python:3.12.8-slim

RUN useradd -ms /bin/bash appuser
USER appuser

ENV PATH="/home/appuser/.local/bin:${PATH}"

WORKDIR /python-api

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
