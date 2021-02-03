---
title: "Basic Data Scraping in Haskell Part 1: HTTP and JSON"
summary: How to work with and model JSON data in Haskell and easily scrape JSON over HTTP
date: 2021-01-05T21:53:59-05:00
keywords: haskell ihp data scrape json http http-conduit aeson web development
---

Haskell is incredibly powerful and rewarding, but also can be frusturating for beginners as common problems
that are easy to solve in more traditional programming languages suddenly appear to be hard again.
Due to many available resources not always being easy to understand, there is a lack of beginner resources for these
issues, while in other languages there is often an abundance of content.
I experienced this myself especially when working with JSON and HTTP. In the articles on this blog, my goal is to expand
the amount of beginner resources for common tasks specifially related to web development in Haskell.

In this short series, I will walk you through
scraping JSON data from the web using basic libraries, and eventually bringing it into the [IHP](https://ihp.digitallyinduced.com) web framework
to be used in an actual application.


### The data

[Attics](https://apps.apple.com/us/app/attics/id1434981632) contains data about tens of thousands of live concerts and recordings of these concerts from over a dozen bands,
which is all sourced from the [Internet Archive's](https://archive.org) [Live Music Archive](https://archive.org/details/etree).
The Archive provides a search API to access data about the recordings, but in order to generate
the data used in Attics for a performance's average rating, number of recordings, and band
metadata, I needed to scrape data from all the recordings, transform and analyze it, and store it persistantly.

The Archive makes it easy to scrape large amounts of data using their [Scrape API](https://archive.org/services/swagger/?url=%2Fservices%2Fsearch%2Fv1%2Fswagger.yaml#/search).
By making a request to `https://archive.org/services/search/v1/scrape`, we get back a collection of items such as

```json
{
  "date": "1966-10-02T00:00:00Z",
  "coverage": "San Francisco, CA",
  "identifier": "gd1966-10-02.sbd.bershaw.9517.shnf",
  "venue": "San Francisco State University",
  "transferer": "Alan Bershaw",
  "downloads": 20676,
  "avg_rating": "4.50",
  "num_reviews": 2,
  "source": "Soundboard"
}
```

Besides `identifier` and `date`, all of these fields are optional.
Let's model this in Haskell as a record named `ArchiveItem`.

```haskell
data ArchiveItem = ArchiveItem
  { identifier :: Text,
    date :: Text,
    collection :: Maybe Text,
    transferer :: Maybe Text,
    downloads :: Maybe Int,
    source :: Maybe Text,
    avgRating :: Maybe Text,
    numReviews :: Maybe Int,
    lineage :: Maybe Text,
    coverage :: Maybe Text,
    venue :: Maybe Text
  }
  deriving (Show, Generic, Eq)
```

Using the [aeson]() library for JSON, we can define an instance of the type class `FromJSON` in order to parse the JSON from the request.
It is possible to auto generate instances for your records, but this gives you much less control of the names of the fields and how the JSON is parsed.
Manually defined, our instance looks like this.

```haskell
instance FromJSON ArchiveItem where
  parseJSON = withObject "ArchiveItem" $ \obj ->
    ArchiveItem
      <$> obj .: "identifier"
      <*> obj .: "date"
      <*> obj .:? "collection"
      <*> obj .:? "transferer"
      <*> obj .:? "downloads"
      <*> obj .:? "source"
      <*> obj .:? "avg_rating"
      <*> obj .:? "num_reviews"
      <*> obj .:? "lineage"
      <*> obj .:? "coverage"
      <*> obj .:? "venue"
```

This code uses a common pattern with the operators `<$>` and `<*>` defined for the `Applicative` type class in order to
create a record type using monadic actions. This code could be equivalently written:

```haskell
instance FromJSON ArchiveItem where
  parseJSON = withObject "ArchiveItem" $ \obj -> do
    identifier <- obj .: "identifier"
    date <- obj .: "date"
    ...
    pure $ ArchiveItem identifier date ...
```

which uses the standard `do` notation to parse the fields and create the record object.

The final piece of data we need to model is the response from the endpoint, which contains some metadata about the request, as well
as the items as we showed above inside the `items` key:

```haskell
data ScrapeResponse = ScrapeResponse
  { scrapeItems :: [ArchiveItem],
    scrapeCursor :: Maybe Text
  }
  deriving (Generic)

instance FromJSON ScrapeResponse where
  parseJSON = withObject "ScrapeResponse" $ \obj ->
    ScrapeResponse
      <$> obj .: "items"
      <*> obj .:? "cursor"
```

The `cursor` field is included for paginating large queries: we'll look into this more later.


### HTTP requests

Working with HTTP was daunting to me when I started writing Haskell due to the many options available.
Today, we'll be using `http-conduit`, which makes dealing with simple requests easy.
Let's define an initial function `scrape :: Text -> IO [ArchiveItem]` which scrapes all the items for a given collection,
and use `http-conduit` to make a request to the endpoint.

```haskell
scrape :: Text -> IO [ArchiveItem]
scrape' collection =
  let url = "https://archive.org/services/search/v1/scrape?fields=avg_rating,venue,coverage,num_reviews,date,downloads,source,transferer,lineage,identifier&q=collection:" <> collection
   in do
        request <- parseRequest (cs url)
        response <- httpJSON request
        let ScrapeResponse {..} = getResponseBody response
        pure scrapeItems
```

A couple key points here: `parseRequest` parses a URL, given as a `String`, into a request object.
It is then passed to `httpJSON`, which automatially parses the response body as JSON. We access this body
using `getResponseBody`. Note we didn't explicitlly give `httpJSON` a type here:
by assigning the result of `getResponseBody response` to a `ScrapeResponse`, GHC is automatially able to infer the
types for us. Go Haskell!

To complicate matters, we need to account for a possible `cursor` included, which we need to include in the next
request in order to get more results. We can do this with a simple refactor:

```haskell
scrape :: Text -> IO [ArchiveItem]
scrape t = scrape' t Nothing

scrape' :: Text -> Maybe Text -> IO [ArchiveItem]
scrape' collection cursor =
  let baseUrl = "https://archive.org/services/search/v1/scrape?fields=avg_rating,venue,coverage,num_reviews,date,downloads,source,transferer,lineage,identifier&q=collection:" <> collection
      url = case cursor of
        Just c -> baseUrl <> "&cursor=" <> c
        Nothing -> baseUrl
   in do
        request <- parseRequest (cs url)
        putStrLn url
        response <- httpJSON request
        let ScrapeResponse {..} = getResponseBody response
        case scrapeCursor of
          Just cursor -> do
            rest <- scrape' collection (Just cursor)
            return $ scrapeItems ++ rest
          Nothing -> return scrapeItems
```

Here we define a helper function which is called recursively with the cursor if it's included in the response.

### Next

Next time, we'll be looking at how to integrate this scraping code into [IHP]() to easily store it persistantly.
Please comment below with any questions -- I'm writing these articles to help those newer to Haskell
solve the problems that I struggled to solve as I was learning, so I'd be happy to help with any of the
problems you encounter as you're learning Haskell.
