# LNCrawler

Similar to [SLWCrawler][SLWC]

### Usage

Run `ruby main.rb`, install missing gems as needed

## Issues

- Not multi-threaded, first run will always be slow
- Merely downloads the page source (no processing)
- Does not download embedded images
- Uses similar `judgment.rb` as [SLWCrawler][SLWC], should extract into separate project

[SLWC]: https://github.com/YongJieYongJie/SLWCrawler
