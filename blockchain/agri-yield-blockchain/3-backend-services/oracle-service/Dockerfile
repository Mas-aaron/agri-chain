FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY oracle_node.py .

ENV ORACLE_NODE_ID=node-university-01
ENV ORACLE_NODE_PORT=8001
ENV AGGREGATOR_URL=http://backend:8000/oracle/trigger

EXPOSE 8001
CMD ["python", "oracle_node.py"]
