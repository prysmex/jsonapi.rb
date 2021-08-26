# JSONAPI.rb :electric_plug:

Here are some _codes_ to help you build your next JSON:API compliable application
easier and faster.

## ToDo

* Uncomment and test `RailsJSONAPI::MediaTypeFilter`, add to the `RailsJSONAPI::Rails::Railtie`#initializer

## Motivation

It's quite a hassle to setup a Ruby (Rails) web application to use and follow
the JSON:API specifications.

The idea is simple, JSONAPI.rb offers an easy way to confiture your application
with code that contains no _magic_ and with little code!

The available features include:

* jsonapi renderer (powered by Fast JSON API)
  * sparse fields
  * includes
* jsonapi_errors renderer
* error handling in controller
* error serializers
  * generic
  * active model
* deserialization (with support for nested deserialization and local-id!)

## How

Mainly by leveraging [Fast JSON API](https://github.com/Netflix/fast_jsonapi) and [jsonapi-deserializable](https://github.com/jsonapi-rb/jsonapi-deserializable)
Thanks to everyone who worked on these amazing projects!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jsonapi.rb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jsonapi.rb

## Usage

This gem contains a `Rails::Railtie` that will:

* register the jsonapi mime type **'application/vnd.api+json'**
* register a parameter parser that will **nest jsonapi request params under the key raw_jsonapi**
* register a **jsonapi** renderer to controllers
* register a **jsonapi_errors** renderer to controllers

Assuming you have a model

```ruby
class User < ActiveRecord::Base
  #local id sent by API client, optional
  attr_accessor :lid
end
```

Now lets define our first serializer and deserializer

see [Fast JSON API guide](https://github.com/Netflix/fast_jsonapi#serializer-definition)
on how to define a serializer.

```ruby
# app/serializers/user_serializer.rb

class UserSerializer
  include FastJsonapi::ObjectSerializer
end
```

```ruby
# app/deserializable/deserializable_user.rb

class DeserializableUser < JSONAPI::Deserializable::Resource
  type
  id
  attributes
end
```

### jsonapi Renderer

By default, a serializer class will be *guessed* when using the`jsonapi` renderer depending on the class of the resource to be rendered. If the resource is a collection, it will use the item's class. An instance of `ClassName` will resolve a `ClassNameSerializer` serializer

You can also specify which serializer to use at a controller level by implementing the `jsonapi_serializer_class` hook method or by passing the **serializer_class** option.

Here's an example:

```ruby
class UserController < ActionController::Base

  # ...

  # override at action level with serializer_class
  def show
    # ...
    render jsonapi: @user, {serializer_class: OtherSerializer}
  end

  private

  # controller level hook
  def jsonapi_serializer_class(resource, is_collection)
    YourCustomSerializer
  end
  
end
```

Here is the list of common options you can pass to the `jsonapi` renderer:

* is_collection
* serializer_class

It also supports any other options or params to be passed to the serializer

#### Default serializer options

Here is a list of hooks that allow you to defined controller level defaults for your serializer options

| serializer option | hook            |
| --------------- | --------------- |
| params | jsonapi_serializer_params |
| meta | jsonapi_meta |
| links | jsonapi_links |
| fields | jsonapi_fields |
| include | jsonapi_include |

```ruby
class UserController < ActionController::Base

  # jsonapi_meta hook is called
  def index_1
    render jsonapi: @user
  end

  # by default jsonapi_meta hook is not called when its option is defined at
  # the action level. Use force_jsonapi_hooks: true to force call
  def index_2
    render jsonapi: @user, { meta: {some_key: 'test'} }
  end

  private

  def jsonapi_meta(resource, meta = {})
    meta[:total] = resource.count if resource.respond_to?(:count)
    meta
  end
  
end
```

If you want to skip the default hooks on a specific controller action you can use the **skip_jsonapi_hooks** option

#### sparse fields and includes

includint `RailsJSONAPI::Controller::Utils` into your controller will give you access to

* jsonapi_include_param
* jsonapi_fields_param

### jsonapi_errors Renderer

### Controller Error Handling

<!-- `RailsJSONAPI::Controller::Errors` provides a basic error handling. It will generate a valid
error response on exceptions from strong parameters, on generic errors or
when a record is not found.

To render the validation errors, just pass it to the error renderer.

To use an exception notifier, overwrite the
`render_jsonapi_internal_server_error` method in your controller.

Here's an example:

```ruby
class MyController < ActionController::Base
  include JSONAPI::Errors

  def update
    record = Model.find(params[:id])

    if record.update(params.require(:data).require(:attributes).permit!)
      render jsonapi: record
    else
      render jsonapi_errors: record.errors, status: :unprocessable_entity
    end
  end

  private

  def render_jsonapi_internal_server_error(exception)
    # Call your exception notifier here. Example:
    # Raven.capture_exception(exception)
    super(exception)
  end
end
``` -->

### Controller Deserialization

<!-- `JSONAPI::Deserialization` provides a helper to transform a `JSONAPI` document
into a flat dictionary that can be used to update an `ActiveRecord::Base` model.

Here's an example using the `jsonapi_deserialize` helper:

```ruby
class MyController < ActionController::Base
  include JSONAPI::Deserialization

  def update
    model = MyModel.find(params[:id])

    if model.update(jsonapi_deserialize(params, only: [:attr1, :rel_one]))
      render jsonapi: model
    else
      render jsonapi_errors: model.errors, status: :unprocessable_entity
    end
  end
end
```

The `jsonapi_deserialize` helper accepts the following options:

 * `only`: returns exclusively attributes/relationship data in the provided list
 * `except`: returns exclusively attributes/relationship which are not in the list
 * `polymorphic`: will add and detect the `_type` attribute and class to the
   defined list of polymorphic relationships

This functionality requires support for _inflections_. If your project uses
`active_support` or `rails` you don't need to do anything. Alternatively, we will
try to load a lightweight alternative to `active_support/inflector` provided
by the `dry/inflector` gem, please make sure it's added if you want to benefit
from this feature. -->

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
