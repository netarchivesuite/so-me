# Youtube harvest

## Mission

Harvest a Youtube resource, consisting of the following parts

* The entry web page with render-specific resources (css & images)
* The video for the page
* Meta-data for the video (author, publish date, description etc.)
* Comments for the video
* Sub-titles for the video, if available

Pack it all in WARCs and provide output linking the resources together.

## Requirements

 * Some sort of Linux variant. OS X might work too and prossibly Windows 10 with the Ubuntu sub-system? Only tested on Ubuntu 18.04.
 * bash, uuidgen, sha1sum, xxd, base32, wget, youtube-dl, youtube-comment-downloader (See "Comment track" below for instructions)

## Bonus

* Embedding of meta-data, comments & sub-titles in the video itself
* Represent linked resources using WARC-headers

## youtube-dl

The central component is [youtube-dl](https://github.com/rg3/youtube-dl), an Open Source project with 16K+ commits specializing in video-download. Besides YouTube, it handles other major video sites.

`youtube-dl` has support for fetching auxiliary information. the relevant ones for the current tasks seems to be
* `--write-info-json` Write video metadata to a .info.json file
* `--all-subs` Download all the available subtitles of the video
* `--sub-lang LANGS` Languages of the subtitles to download (optional) separated by commas
* `--embed-subs` Embed subtitles in the video (only for mp4, webm and mkv videos)
* `--add-metadata` Write metadata to the video file
* `--recode-video FORMAT` Encode the video to another format if necessary (currently supported: mp4|flv|ogg|webm|mkv|avi)

Sample: `youtube-dl --write-info-json -f bestvideo+bestaudio --all-subs --embed-subs --add-metadata --recode-video mkv 'https://www.youtube.com/watch?v=SB6kRExUl-k'`

Short sample with subtitles & comments: https://www.youtube.com/watch?v=0i8evu26bY4

## Comment track

It seems that youtube-dl *does not* support downloading of comments: [issue #16128](https://github.com/rg3/youtube-dl/issues/16128). Another tool is needed for that. Perform the actions below in the `youtube`-folder where this `README.md` is located.

```
git clone https://github.com/egbertbouman/youtube-comment-downloader
pip install requests
pip install lxml
pip install cssselect
chmod 755 youtube-comment-downloader/downloader.py
```
Test with
```
youtube-comment-downloader/downloader.py --youtubeid SB6kRExUl-k --output SB6kRExUl-k.comments_$(date +%Y%m%d-%H%M).json
```

## Harvest

Tying it all together: Using a list of YouTube video-IDs as input, for each video-ID

* Use `wget` for fetching the wbpage + images + css and append it to a WARC (or create a new WARC if it is the first entry in the video-ID-list)
* Use `youtube-dl` to download video + subtitles + meta-data
* Use `youtube-comment-downloader` to fetch the comments
* Pack the video and all the meta-data into the WARC, immediately after the wget-output and also marked with WARC-headers tying them together

The script `youtube_harvest.sh` takes a list of YouTube-URLs, either from a file or directly, and performs the actions above. Sample usage:
```
./youtube_harvest.sh -f sample_urls.dat
```
This produces the file `youtube_YYYYmmdd-HHMM.warc` with the data as well as the file `youtube_YYYYmmdd-HHMM.map.csv` connecting the YouTube-URL, video-URL, metadata-URL, comments-URL and subtitle-URLs in the WARC.

## Contact

This Proof Of Concept were hacked together by Toke Eskildsen, toes@kb.dk.
