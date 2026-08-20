FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY main.py requirements.txt ./
RUN apk add --no-cache python3 py3-pip && pip3 install -r requirements.txt
EXPOSE 8080
CMD ["python3", "main.py"]
