FROM node:21-alpine

ADD package.json yarn.lock ./
RUN yarn install

ADD central2.js .

CMD ["node", "central2.js"]
