#!/bin/bash

echo -n 'checking ruby version: '
type ruby > /dev/null 2>&1 || {
    echo >&2
    echo >&2 '    ruby is not found'
    echo >&2 '    Please install ruby'
    exit 1
}
ruby -e 'if RUBY_VERSION < "2.1.0"; exit 1; end' || {
    echo >&2
    echo >&2 '    ruby version is too old'
    echo >&2 '    Please install ruby >= 2.1.0'
    exit 1
}
echo 'OK'

echo 'installing bundler'
gem install bundler || {
    echo >&2 '    failed to install bundler'
    echo >&2 '    please check network setting'
    exit 1
}
type rbenv > /dev/null 2>&1 && {
    rbenv rehash
}

echo 'installing other gems'
bundle install || {
    echo >&2 '    failed to install other gems'
    echo >&2 '    please check network setting'
    exit 1
}
