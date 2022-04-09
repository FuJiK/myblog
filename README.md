# nuxt-content-article

The [content module](https://content.nuxtjs.org/) is a git files based headless CMS that provides powerful features when it comes to write blogs, documentation sites or just adding content to any regular website. In this post we will go through most of the benefits of this module and discover how we can create a blog with it.

For detailed explanation on how to create this blog, check out [the tutorial](https://nuxtjs.org/blog/creating-blog-with-nuxt-content).

Click here to view the [demo](https://blog-with-nuxt-content.netlify.app/)

![demo of blog](https://res.cloudinary.com/nuxt/video/upload/v1588091670/demo-blog-content_shk6kw.jpg)

## Build Setup

```bash
# install dependencies
$ yarn

# serve with hot reload at localhost:3000
$ yarn dev

# generate static project
$ yarn generate

# view a production version of your app
$ yarn start
```

'''bash
以下でも実行可能
# npm installでパッケージをインストール
$ npm install

# nuxt コマンドを実行
$ npm run dev 

# nuxt build コマンドを実行
$ npm run build 

# nuxt start コマンドを実行
$ npm run start

# nuxt generate コマンドを実行
$ npm run generate
'''

# git について
$ git add .
$ git commit -m "コメント"
$ git push

これやれば、ブログはgithub Actions が２分ほどで、いい感じにブランチにCDしてくれる。