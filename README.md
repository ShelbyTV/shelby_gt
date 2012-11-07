# shelby_gt

This repository contains the Shelby GT API server code.

## Sitemaps

### Overview

Sitemaps are generated and stored on the API server, since it already has all the Rails models available for reading information easily from the database.

But since the sitemaps all point to shelby.tv URLs instead of api.shelby.tv URLs, a redirect is maintained in the shelby.tv nginx config file to make it easy to submit a sitemap index URL that matches the shelby.tv domain.

Robots.txt has also been modified to specify the sitemap index file. Both api.shelby.tv and shelby.tv are verified domains inside of Google Webmaster Tools.

### Generating

The main goal during generation is to iterate over all videos in the Shelby database and add URLs to the sitemap for each video's SEO page.

The `sitemap_generator` gem (https://github.com/kjvarga/sitemap_generator) is used to create the sitemap index and sitemap files.

The code for generating the sitemap is at `shelby_gt/config/sitemap.rb`. The code here is mostly straightforward -- the only important concept to grasp is that iterating over all the videos in the database would consume too much memory if the mongomapper identity map were allowed to cache all the objects. So the code explicitly clears the monogmapper identity map to make sure memory usage is kept to a minimum.

The basic process of generating the sitemap is:

`ssh gt@api.shelby.tv`

`cd api/current`

`RAILS_ENV=production rake sitemap:refresh:no_ping`

### Web vs. Video

Originally both web (just URL) and video sitemap files were generated. Video sitemaps must contain much more data -- the video title, description, thumbnail URL, etc.

Generating the video sitemap takes much more time and storage space.

Google can just as easily parse the video metadata out from the page using the metadata from the player's iframe, or using metadata on the containing page in RDFa, Facebook Share, or schema.org format.

So for large amounts of videos, it seems preferable to only generate a web sitemap and trust the search engines to correctly parse the metadata to be included in video search.

### Storage

The sitemap files currently are generated into and stored inside `api/current/public/system`. This `public/system` directory stays constant throughout API server updates, so the sitemap files don't need to be regenerated all the time.

For a since of storage requirments -- 18.5 million URLs currently take roughly 560 MB of storage for the sitemap files.

### Runtime

An example runtime for generating web-only (no video) sitemaps is:

`Sitemap stats: 18,483,514 links / 370 sitemaps / 400m42s`

### Future Improvements

One could make incremental sitemap additions much faster by storing the mongodb id of the last video processed in a file. The sitemap generation code could be altered to read in this id and only add new videos to the existing sitemap.

## C APIs

### Overview

The C APIs provide a more efficient way of querying the Shelby database for substantial amounts of data, processing that data, and returning it as a JSON data structure to the calling code.

Rails, accessing mongodb through mongomapper, must convert the mongodb bson data into a Ruby (Rails) data structure. Eventually this goes through other manipulations to convert the Ruby data structure back into JSON for output.

The C API code avoids one translation of the data by keeping the mongodb data in its native bson format. It also is more efficient at doing the JSON conversion, yielding overall much improved performance over Rails APIs performing the same tasks.

### C Code

The C code itself is stored in the badly named `cpp` directory (it was named when there was still C++ code in the mix as well).

Source code is in `cpp/source` or `cpp/lib`. `Sconstruct` and the `site_scons` directory contain the scons code for building. `scons` is what the cool kids use nowadays -- only old school folks use `make`.

#### Preparation

Two of the libraries used by the C APIs (`mongo-c-driver` and `yajl`) are actually git submodules. To initialize and update the git submodules, one must do the following:

- Run `git submodule init` from the top level of `shelby_gt`
- Run `git submodule update` from the top level of `shelby_gt`

These commands must complete successfully to guarantee functionality. If you see any errors during this process, you must debug and resolve them.

These commands are safe to run multiple times, so if you've forgotten whether or not you've done so on a particular tree, you can always run them again.

It should be safe to run these commands from either inside the vagrant VM or just from your Mac, as long as git is installed and working in both places.

#### Building

Once the submodules have been initialized and updated, the next step is ensuring that you have `scons` available inside your vagrant VM. Run this command to install `scons`:

`sudo apt-get install scons`

Once this successfully completes, inside your vagrant VM, do the following:

`cd shelby_gt/cpp`

`scons`

The C APIs should build successfully.

To clean up the build tree completely, removing all build output, do:

`cd shelby_gt/cpp`

`scons -c`

Part of the building process is that final binaries are copied into `cpp/bin`. These are being checked into the git tree at the moment so that compilation doesn't have to happen during API server deployment.

The build process also automatically generates debug binaries with complete debugging symbols for use with `gdb`. These are located in the `cpp/build` directory after running `scons` and are named with the API executable name with `-debug` appended.

#### Database

The `mongo-c-driver` is a very simple `mongodb` driver. One feature it lacks is the ability to automatically balance requests between the primary and secondary servers in a replica set. It also has issues during primary failover if the primary machine is completely unreachable, since it waits for the HTTP timeout of the first machine in its replica set list before trying other machines.

To get around these issues, the C APIs connect to locally running `mongos` processes that are designed to handle the connections to replica sets and shards, doing proper failover and load-balancing.

Also, it's important to note that the C APIs all take an environment parameter which determines the database servers to use. This allows the same binary to be used for connecting to development, test, and production databases.

#### Hacks and Gotchas

The main remaining hack is in building the `mrjson` library and having it properly consume the `yajl` library headers.

Inside of `cpp/lib/mrjson/yajl-hacks` is a directory full of symlinks to header files that get populated with `git submodule update`. The `mrjson` library consumes the `yajl` header files from this location to avoid some silly problems with paths.

Normally when `yajl` is installed as a system library, this isn't a problem. But in our case, we compile all C API executables as static programs, both for ease-of-use as well as launch speed, so consuming the correct version of `yajl` and its headers from the source tree is preferrable.

### Rails Metal Controllers

The C APIs are executed from within Rails Metal Controllers. Mostly these controllers are just taking URL parameters and passing them to the C APIs.

The C APIs are just executed using backticks to execute the programs and capture the output. Launching C APIs is somewhat slow (~30-50 ms), but some time is shaved off by using Rails Metal Controllers, which load less Rails code and save ~30ms over regular Rails controllers.

Because of the current launch time for C APIs, it only makes sense to convert APIs that have significant runtimes in Rails. See the next section for modifications that could be made to make almost any APIs faster in C.

Note that having the controllers contain the word "Metal" in them makes them easy to identify in NewRelic performance stats.

### Other Future Improvements

In an ideal world, the C APIs would be even faster by making them be continuously-running single API-servers that communicate with nginx over FastCGI.

Basically, FastCGI support would be added to each API program, and it would be run as a long-running daemon process on the API server machine. Requests to these C APIs would bypass Rails entirely.

The main problem with this approach is w.r.t. authentication and cookies. Rails by default uses its own Marshal format for cookies, for which there doesn't seem to be an existing C library that's easy to use.

However, other folks have handled split Rails/C authentication by changing the default Rails serialization format to another format easily understood by multiple languages -- MessagePack (http://msgpack.org/) seems to be a popular option.

In addition to this, the C APIs would need extra work to ensure no memory leaks, become multithreaded if necessary to handle more concurrent requests, etc.