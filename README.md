# README

## Parallel_tests

```ruby
# Run all tests in parallel
bundle exec parallel_test spec/ -t rspec --first-is-1

# Run only system tests in parallel
bundle exec parallel_test spec/system/ -t rspec --first-is-1

# Specify custom worker count
bundle exec parallel_test spec/ -t rspec -n 4 --first-is-1
```
