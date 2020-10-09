---
layout: post
title: What are people listening to on Attics?
summary: Analyzing API logs with Unix tools
date: 2019-08-17T11:30:03+00:00
---


> **Update 2020/10/08:** Since writing this, the architecture of Attics has changed considerably.
It now uses serverless Go functions deployed on AWS which I have found much easier to maintain.
Look for a upcoming post explaining this new architecture!

I recently rewrote the API that serves
[Attics](https://apps.apple.com/us/app/attics/id1434981632) its data
from a small Rails app to Go. With this transition, I added a simple
logging middleware that runs on every request to the API.

```go
func (app *App) logRequest(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		h(w, r)
		app.logger.Printf("%s %s\n", r.Method, r.URL.Path)
	}
}
```

In production, this produces logs that look like

```sh
$ docker-compose logs attics_api | tail

attics_api_1  | 2019/08/17 16:24:57 GET /v1.1/GratefulDead/top_shows
attics_api_1  | 2019/08/17 16:25:00 GET /v1.1/GratefulDead/1969/1969-12-31
attics_api_1  | 2019/08/17 16:25:02 GET /v1.1/sources/gd69-12-31.sbd.gardner.7373.sbeok.shnf
attics_api_1  | 2019/08/17 16:31:24 GET /v1.1/GratefulDead/top_shows
attics_api_1  | 2019/08/17 16:31:31 GET /v1.1/GratefulDead/1965/1965-11-01
attics_api_1  | 2019/08/17 16:31:39 GET /v1.1/GratefulDead/1969/1969-11-02
attics_api_1  | 2019/08/17 16:31:41 GET /v1.1/sources/gd69-11-02.sbd.goodbear.1125.sbefail.shnf
attics_api_1  | 2019/08/17 16:37:09 GET /v1.1/GratefulDead/top_shows
attics_api_1  | 2019/08/17 16:37:15 GET /v1.1/GratefulDead/1989/1989-10-09
attics_api_1  | 2019/08/17 16:37:16 GET /v1.1/sources/gd89-10-09.sbd.serafin.7721.sbeok.shnf
```

The latest update to Attics which moved to this API hasn't even been
out a week yet, and it's already received thousands of requests!

```sh
$ docker-compose logs attics_api | wc -l
5478
```

I'm curious which shows people are listening to, so let's use some
shell scripting to count the number of times each show has been
visited. The log for a visit to the endpoint for getting the songs for
a source (Archive speak for a recording) looks like

```
attics_api_1  | 2019/08/17 21:08:44 GET /v1.1/sources/gd79-10-27.sbd.clugston.13980.sbeok.shnf
```

Let's get all the lines like this using `grep`.

```sh
$ docker-compose logs attics_api | grep 'sources'

attics_api_1  | 2019/08/17 21:19:20 GET /v1.1/sources/gd1992-06-11.sbd.miller.90105.sbeok.flac16
attics_api_1  | 2019/08/17 21:20:35 GET /v1.1/sources/gd1975-06-17.aud.unknown.87560.flac16
attics_api_1  | 2019/08/17 21:20:45 GET /v1.1/sources/gd75-08-13.fm.vernon.23661.sbeok.shnf
attics_api_1  | 2019/08/17 21:20:56 GET /v1.1/sources/gd76-06-09.set2-sbd.gardner.5426.sbeok.shnf
attics_api_1  | 2019/08/17 21:21:11 GET /v1.1/sources/gd73-02-09.sbd.bertha-fink.14939.sbeok.shnf
...
```

Every source has the date in its identifier, either in the form
`XXXX-XX-XX` or `XX-XX-XX`. The latter will match all the cases of the
former, so let's use `grep` again and search for the latter pattern.

```sh
$ docker-compose logs attics_api \
    | grep 'sources' \
    | grep -o -E '[0-9]{2}-[0-9]{2}-[0-9]{2}'

92-06-12
92-06-17
92-06-18
72-05-03
92-06-11
75-06-17
75-08-13
76-06-09
73-02-09
...
```

The `-o` switch tells `grep` to print only the text in the line that
matches the pattern, and `-E` allows us to use the `{2}` syntax.

Now we need to get a count of how many time each date
appears. Luckily, the `uniq` tool can do this with the `-c`
flag. However, `uniq` expects all the unique lines to be adjacent, so
that for example each occurrence of `92-06-12` needs to be grouped
together. We can easily do this with `sort`.

```sh
$ docker-compose logs attics_api \
    | grep 'sources' \
    | grep -o -E '[0-9]{2}-[0-9]{2}-[0-9]{2}' \
    | sort \
    | uniq -c

1 95-06-04
5 95-06-18
1 95-06-19
3 95-06-22
2 95-06-24
1 95-06-25
1 95-06-27
1 95-06-28
12 95-06-30
...
```

Perfect! Now we can get the most visited shows by sorting this list
numerically and reversing it with the `-g` and `-r` flags
respectively.

```sh
$ docker-compose logs attics_api \
    | grep 'sources' \
    | grep -o -E '[0-9]{2}-[0-9]{2}-[0-9]{2}' \
    | sort \
    | uniq -c \
    | sort -g -r \
    | head

39 77-05-08
37 69-08-16
29 91-06-17
28 89-07-07
27 71-08-06
26 65-11-03
24 76-06-09
23 87-09-18
22 82-10-10
22 80-05-16
```

And we're done. There are some classics here like 77-05-08 and
71-08-06, but also quite a few I personally haven't listened to, so I
have some catching up to do!

Unix tools are great for quickly analyzing text like this. Knowing
your way around the basic tools like `grep` can get you far alone, and if
you get stuck, the `man` pages are always there to help.
