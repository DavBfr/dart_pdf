Napkin README

In order to synk Napkin fork with the source repository, you can follow instructions from https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/configuring-a-remote-repository-for-a-fork

One time local setup:

```
$ git remote -v
> origin  https://github.com/YOUR-USERNAME/dart_pdf.git (fetch)
> origin  https://github.com/YOUR-USERNAME/dart_pdf.git (push)
```

```
git remote add upstream https://github.com/DavBfr/dart_pdf.git
```

```
$ git remote -v
> origin  https://github.com/YOUR-USERNAME/dart_pdf.git (fetch)
> origin  https://github.com/YOUR-USERNAME/dart_pdf.git (push)
upstream	https://github.com/DavBfr/dart_pdf.git (fetch)
upstream	https://github.com/DavBfr/dart_pdf.git (push)
```

Syncing the fork (https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork):

```
$ git fetch upstream
```

```
$ git checkout napkin
```

```
$ git merge upstream/master
```

Resolve potential conflicts, push, tag...