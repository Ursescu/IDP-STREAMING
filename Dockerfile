FROM node:latest
WORKDIR /usr/src/app
COPY package*.json ./
ADD setup_ffmpeg.sh /root

RUN /root/setup_ffmpeg.sh
RUN npm install

# Bundle app source
COPY . .

EXPOSE 80
CMD [ "npm", "start" ]