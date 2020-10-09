---
title: "A New Attics Architecture"
date: 2020-10-09T10:23:52-04:00
summary: Streaming live music using a serverless architecture on AWS
---

During my internship at Capital One last summer, I was able to get my feet wet with AWS for the first time.
While exploring all the different services available and learning about their power, I was becoming
more and more frusturated with the lack of control I had for my old architecture for Attics -- a
single Go program deployed to a DigitalOcean droplet using Docker and a local SQLite database. This was a reliable system
but lacked flexibility.
So to both improve Attics and learn tons of new things, I spent about
two weeks of fun nights learning the basics of AWS and migrating code. At the end, I deployed the new Attics architecture.


## The Architecture

![Attics Architecture](/img/attics2.png)

### Attics Clients

The story starts with the users of Attics. Currently the only way to access the platform is on
[Attics for iOS](https://apps.apple.com/us/app/attics/id1434981632), but a web version at attics.io is in development currently.
Both clients get the data about the live shows from https://api.attics.io, which
is a domain managed by AWS Route 53.

### Route 53

[Route 53](https://aws.amazon.com/route53/) is an easy way to manage domains, and also includes some nice functionality for health checks.
I purchased attics.io, and obtained a certificate for the domain and its wildcard to ensure
all content can be served over HTTPS. In Route 53, requests to the API domain are routed to API Gateway.

### API Gateway

[API Gateway](https://aws.amazon.com/api-gateway/) defines the public interface Attics clients can use to access the app data.
Using the API Gateway console, I defined all of the endpoints needed for the apps.

![API Gateway setup](/img/apigateway.png)

For example, try going to https://api.attics.io/v2/bands to get a JSON response
of all the bands currently hosted on Attics. Pretty cool! But how is this data generated?

### Lambda

[AWS Lambda](https://aws.amazon.com/lambda/) hosts all of Attics' serverless functions that query the database to get the data for each request.
Each API Gateway method is linked to a Lambda function written in Go that takes the request data, queries the database,
transforms the data as necessary, and returns a response that gets sent back to the client.

### DynamoDB

The database that stores all of Attics' data is [DynamoDB](https://aws.amazon.com/dynamodb/), a "fast and flexible NoSQL database service for any scale".
To be honest, before building the new Attics with DynamoDB, I had a very negative view of NoSQL databases.
As it turned out, just like our negative views of most things, it was just because I didn't understand it!
Once I grasped Single Table Design with the help of [this excellent blog post](https://www.alexdebrie.com/posts/dynamodb-single-table/) (and saw how cheap DynamoDB is compared to managed SQL 👀) things started making much more sense,
and I ended up really enjoying the development experience with DynamoDB and NoSQL.
Having a persistent database managed in the cloud is a fantastic benefit compared to building
a SQLite file from scrach on every deploy!

### CloudWatch

Bringing the entire architecture together is [AWS CloudWatch](https://aws.amazon.com/cloudwatch/),
a fantastic serivce that allows you to create monitoring dashboards, setup alarms in case any of the services
go wrong, and define timed events that connect to Lambda functions (like cron on Linux, but in the cloud).
This is where hosting Attics on AWS has really made my life better. It's fantastic being able to track request counts,
have working health checks and alarms, and being able to schedule events easily.

The main event used is the Archive.org scrape event, which starts a Lambda function that gets all bands from DynamoDB,
adds them to a Simple Queue Service queue, which in turn triggers a Lambda function to scrape that band from the Internet Archive.
Due to the long compute time of the scrape for some bands, this was something I was never able to get working reliably on my old architecture.

## Conclusion

At first, this architecture seems like all of this is a huge step up in complexity from a single Go process running on a droplet.
Trust me, I definitely felt that during some frusturating points in development.
However, there are tons of great resources for learning AWS and gettings past these hurdles.
And once I finished, I found using cloud services allows me to have a much more reliable, better monitored service
that I can easily extend in the future and has the entire power of AWS available to me, all at
only a slightly higher cost.