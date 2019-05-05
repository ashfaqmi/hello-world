FROM node:6.14.2
EXPOSE 8080
COPY helloWorld.js .
CMD node helloWorld.js
