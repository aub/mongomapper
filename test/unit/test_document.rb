require 'test_helper'
require 'models'

class DocumentTest < Test::Unit::TestCase
  context "The Document Class" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        set_collection_name 'test'
      end
      @document.collection.remove
    end
    
    should "have logger method" do
      @document.logger.should == MongoMapper.logger
      @document.logger.should be_instance_of(Logger)
    end
    
    should "track its descendants" do
      MongoMapper::Document.descendants.should include(@document)
    end

    should "use default database by default" do
      @document.database.should == MongoMapper.database
    end

    should "have a connection" do
      @document.connection.should be_instance_of(Mongo::Connection)
    end

    should "allow setting different connection without affecting the default" do
      conn = Mongo::Connection.new
      @document.connection conn
      @document.connection.should == conn
      @document.connection.should_not == MongoMapper.connection
    end

    should "allow setting a different database without affecting the default" do
      @document.set_database_name 'test2'
      @document.database_name.should == 'test2'
      @document.database.name.should == 'test2'

      another_document = Class.new do
        include MongoMapper::Document
        set_collection_name 'test'
      end
      another_document.database.should == MongoMapper.database
    end
    
    should "default collection name to class name tableized" do
      class ::Item
        include MongoMapper::Document
      end
      
      Item.collection.should be_instance_of(Mongo::Collection)
      Item.collection.name.should == 'items'
    end
    
    should "default collection name of namespaced class to tableized with dot separation" do
      module ::BloggyPoo
        class Post
          include MongoMapper::Document
        end
      end

      BloggyPoo::Post.collection.should be_instance_of(Mongo::Collection)
      BloggyPoo::Post.collection.name.should == 'bloggy_poo.posts'
    end

    should "allow setting the collection name" do
      @document.set_collection_name('foobar')
      @document.collection.should be_instance_of(Mongo::Collection)
      @document.collection.name.should == 'foobar'
    end

    should 'allow extensions to Document to be appended' do
      module Extension
        def test_this_extension; end
      end
      MongoMapper::Document.append_extensions(Extension)
      article = Class.new
      article.send(:include, MongoMapper::Document)
      article.should respond_to(:test_this_extension)
    end

    should 'add appended extensions to classes that include Document before they are added' do
      module Extension
        def test_this_extension; end
      end
      article = Class.new
      article.send(:include, MongoMapper::Document)
      MongoMapper::Document.append_extensions(Extension)
      article.should respond_to(:test_this_extension)
    end

    should 'allow inclusions to Document to be appended' do
      module Inclusion
        def test_this_inclusion; end
      end
      MongoMapper::Document.append_inclusions(Inclusion)
      article = Class.new
      article.send(:include, MongoMapper::Document)
      article.new.should respond_to(:test_this_inclusion)
    end

    should 'add appended inclusions to classes that include Document before they are added' do
      module Inclusion
        def test_this_inclusion; end
      end
      article = Class.new
      article.send(:include, MongoMapper::Document)
      MongoMapper::Document.append_inclusions(Inclusion)
      article.new.should respond_to(:test_this_inclusion)
    end
  end # Document class
  
  context "Documents that inherit from other documents" do
    should "default collection name to inherited class" do
      Message.collection_name.should == 'messages'
      Enter.collection_name.should   == 'messages'
      Exit.collection_name.should    == 'messages'
      Chat.collection_name.should    == 'messages'
    end
    
    should "default associations to inherited class" do
     Message.associations.keys.should include("room")
     Enter.associations.keys.should   include("room")
     Exit.associations.keys.should    include("room")
     Chat.associations.keys.should    include("room")
   end
    
    should "track subclasses" do
      Message.subclasses.should == [Enter, Exit, Chat]
    end
  end

  context "An instance of a document" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        set_collection_name 'test'

        key :name, String
        key :age, Integer
      end
      @document.collection.remove
    end
    
    should "have access to logger" do
      doc = @document.new
      doc.logger.should == @document.logger
      doc.logger.should be_instance_of(Logger)
    end

    should "have access to the class's collection" do
      doc = @document.new
      doc.collection.name.should == @document.collection.name
    end

    should "use default values if defined for keys" do
      @document.key :active, Boolean, :default => true

      @document.new.active.should be_true
      @document.new(:active => false).active.should be_false
    end
    
    should "use default values if defined even when custom data type" do
      @document.key :window, WindowSize, :default => WindowSize.new(600, 480)
      
      doc = @document.new
      doc.window.should == WindowSize.new(600, 480)
    end

    context "root document" do
      should "have a nil _root_document" do
        @document.new._root_document.should be_nil
      end

      should "set self to the root document on embedded documents" do        
        klass = Class.new do
          include MongoMapper::Document
        end
        
        pets = Class.new do
          include MongoMapper::EmbeddedDocument
        end
        klass.many :pets, :class => pets
        
        doc = klass.new(:pets => [{}])
        doc.pets.first._root_document.should == doc        
      end
    end

    context "new?" do
      should "be true if no id" do
        @document.new.new?.should be_true
      end
      
      should "be true if id but using custom id and not saved yet" do
        @document.key :_id, String
        doc = @document.new
        doc.id = '1234'
        doc.new?.should be_true
      end
    end

    context "clone" do
      should "not set the id" do
        doc = @document.create(:name => "foo", :age => 27)
        clone = doc.clone
        clone.should be_new
      end

      should "copy the attributes" do
        doc = @document.create(:name => "foo", :age => 27)
        clone = doc.clone
        clone.name.should == "foo"
        clone.age.should == 27
      end
    end

    context "equality" do
      setup do
        @oid = Mongo::ObjectID.new
      end
      should "be equal if id and class are the same" do
        (@document.new('_id' => @oid) == @document.new('_id' => @oid)).should be(true)
      end

      should "not be equal if class same but id different" do
        (@document.new('_id' => @oid) == @document.new('_id' => Mongo::ObjectID.new)).should be(false)
      end

      should "not be equal if id same but class different" do
        @another_document = Class.new do
          include MongoMapper::Document
          set_collection_name 'test'
        end

        (@document.new('_id' => @oid) == @another_document.new('_id' => @oid)).should be(false)
      end
    end
  end # instance of a document
end # DocumentTest
