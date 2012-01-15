# Listen [![Build Status](https://secure.travis-ci.org/guard/listen.png?branch=master)](http://travis-ci.org/guard/listen)

Work in progress...

The Listen gem listens to file modifications and notifies you about the changes.

Here the API that should be implemented, feel free to give your feeback via [Listen issues](https://github.com/guard/listener/issues)

## Block API

### One dir

``` ruby
Listen.to(dir, filter: '**/*', ignore: paths) do |modified, added, removed|
  ...
end
```

### Multiple dir

``` ruby
Listen.to do
  path(dir1, filter: '**/*', ignore: paths) do |modified, added, removed|
    ...
  end
  path(dir2, filter: '**/*', ignore: paths) do |modified, added, removed|
    ...
  end
  ....
end
```

Question: if dir2 is a child of dir1 both path block will be call if a file inside dir2 is modified right?

## "Object" API

``` ruby
listen = Listen.to(dir)
listen.ignore('.git')
listen.filter('*.rb')
listen.modification(&on_modification)
listen.addition(&on_addition)
listen.removal(&on_removal)
listen.start # enter the run loop
listen.stop
```

### Chainable

``` ruby
Listen.to(dir).ignore('.git').filter('*.rb').modification(&on_modification).addition(&on_addition).removal(&on_removal).start # enter the run loop
```

### Multiple dir support available via Thread.

``` ruby
listen  = Listen.ignore('.git')
styles  = listen.to(dir1).filter('*.css').addition(&on_style_addition)
scripts = listen.to(dir2).filter('*.js').addition(&on_script_addition)

Thread.new { styles.start } # enter the run loop
Thread.new { scripts.start } # enter the run loop
```