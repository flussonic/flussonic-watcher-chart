FROM node:21

ADD package.json ./
RUN yarn install

ADD central2.js .

CMD ["node", "central2.js"]
