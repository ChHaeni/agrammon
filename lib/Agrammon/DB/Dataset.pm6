use v6;
use Agrammon::DB;
use Agrammon::DB::Tag;
use Agrammon::DB::User;

#| Error when a dataset already exists for the user.
class X::Agrammon::DB::Dataset::AlreadyExists is Exception {
    has Str $.dataset-name is required;
    method message {
        "Dataset '$!dataset-name' already exists."
    }
}

#| Error when dataset couldn't be renamed.
class X::Agrammon::DB::Dataset::RenameFailed is Exception {
    has Str $.dataset-name is required;
    has Str $.old-name is required;
    has Str $.new-name is required;
    method message {
        "Dataset '$!dataset-name' couldn't be renamed from '$!old-name' to '$!new-name'."
    }
}

class Agrammon::DB::Dataset does Agrammon::DB {
    has Int  $.id;
    has Str  $.name;
    has Bool $.read-only;
    has Str  $.model;
    has Str  $.comment;
    has Str  $.version;
    has Int  $.records;
    has DateTime $.mod-date;
    has $.data;
    has Agrammon::DB::Tag  @.tags;
    has Agrammon::DB::User $.user;

    method create {
        self.with-db: -> $db {
            my $ds = $db.query(q:to/DATASET/, $!name, $!user.id, $!version, $!comment, $!model, $!read-only);
                INSERT INTO dataset (dataset_name, dataset_pers,
                                     dataset_version, dataset_comment,
                                     dataset_model, dataset_readonly
                                    )
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING dataset_id, dataset_mod_date
            DATASET

            my @d = $ds.array;
            $!id = @d[0];
            $!mod-date = @d[1];
        }
        return self;
    }

    method rename(Str $new) {
        self.with-db: -> $db {
            # old and new name are identical
            die X::Agrammon::DB::Dataset::RenameFailed.new(:dataset-name($new), :old-name($!name), :new-name($new)) if $new eq $!name;

            note "Rename $!name -> $new for user " ~ $!user.id;
            my $ret = $db.query(q:to/SQL/, $new, $!name, $!user.id);
                UPDATE dataset SET dataset_name = $1
                 WHERE dataset_name = $2 AND dataset_pers = $3
                RETURNING dataset_name
            SQL
            note "rows=" ~ $ret.rows;
            note "value=" ~ $ret.value if $ret.rows;
            # new dataset name already exists
            CATCH {
                when /unique/ {
                    die X::Agrammon::DB::Dataset::AlreadyExists.new(:dataset-name($new));
                }
            }

            # update failed
            die X::Agrammon::DB::Dataset::RenameFailed.new(:dataset-name($new), :old-name($!name), :new-name($new)) unless $ret.rows;

            # rename suceeded
            $!name = $new;
        }
        return self;
    }

    method !clone($new) {
        my $dataset = Agrammon::DB::Dataset.new(:name($new));
        warn "clone($new) not yet implemented";
        return $dataset;
    }

    method submit($email) {
        my $new-dataset = self!clone("Clone of $!name");

        warn "Sending mail for submit($email) not yet implemented";
        return $new-dataset;
    }

    method lookup {
        self.with-db: -> $db {
            my $username = $!user.username;
            my $results = $db.query(q:to/DATASET/, $!user.id, $!name);
            SELECT dataset_id
              FROM dataset LEFT JOIN pers ON dataset_pers=pers_id
             WHERE dataset_pers = $1
               AND dataset_name = $2
            DATASET
            $!id = $results.value;
        }
        return self;
    }

    method set-tag($tagName) {
        self.with-db: -> $db {
            my $tag = Agrammon::DB::Tag.new( :name($tagName), :user($!user)).lookup;
            if $tag.id {
                $db.query(q:to/DATASET/, $tag.id, $!id);
                    INSERT INTO tagds (tagds_tag, tagds_dataset)
                    VALUES ($1, $2)
                    RETURNING tagds_id
               DATASET
            }
        }
        return self;
    }

    method remove-tag($tagName) {
        self.with-db: -> $db {
            my $tag = Agrammon::DB::Tag.new( :name($tagName), :user($!user)).lookup;
            if $tag.id {
                $db.query(q:to/DATASET/, $tag.id, $!id);
                    DELETE FROM tagds
                    WHERE tagds_tag = $1 AND tagds_dataset = $2
                DATASET
            }
        }
        return self;
    }

    method load {
        self.with-db: -> $db {
            my $username = $!user.username;
            my $results = $db.query(q:to/DATASET/, $username, $!name);
            SELECT data_var, data_val, data_instance_order, branches_data, data_comment
              FROM data_view LEFT JOIN branches ON (branches_var=data_id)
             WHERE data_dataset=dataset_name2id($1,$2)
               AND data_var not like '%::ignore'
             ORDER BY data_instance_order ASC, data_var
            DATASET
            $!data = $results.arrays;
        }
        return self;
    }

    method load-branch-data {
        warn "*** load-branch-data() not yet implemented";
        my @data;
        # self.with-db: -> $db {
        #     my $username = $!user.username;
        #     my $results = $db.query(q:to/DATASET/, $username, $!name);
        #     SELECT data_var, data_val, data_instance_order, branches_data, data_comment
        #       FROM data_view LEFT JOIN branches ON (branches_var=data_id)
        #      WHERE data_dataset=dataset_name2id($1,$2)
        #        AND data_var not like '%::ignore'
        #      ORDER BY data_instance_order ASC, data_var
        #     DATASET
        #     $!data = $results.arrays;
        # }
        return @data;
    }

    method store-branch-data(%data) {
        warn "*** store-branch-data() not yet implemented";
        my @data;
        # self.with-db: -> $db {
        #     my $username = $!user.username;
        #     my $results = $db.query(q:to/DATASET/, $username, $!name);
        #     SELECT data_var, data_val, data_instance_order, branches_data, data_comment
        #       FROM data_view LEFT JOIN branches ON (branches_var=data_id)
        #      WHERE data_dataset=dataset_name2id($1,$2)
        #        AND data_var not like '%::ignore'
        #      ORDER BY data_instance_order ASC, data_var
        #     DATASET
        #     $!data = $results.arrays;
        # }
        return @data.keys.elems;
    }

    method store-comment($comment) {

        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $comment, $username, $!name);
            UPDATE dataset SET dataset_comment = $1
             WHERE dataset_id=dataset_name2id($2,$3)
            RETURNING dataset_comment
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method !store-variable-comment($var, $comment) {

        return unless $var and $comment.defined;
        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $comment, $username, $!name, $var);
            UPDATE data_new SET data_comment = $1
             WHERE data_dataset=dataset_name2id($2,$3) AND data_var=$4
                                                       AND data_instance IS NULL
            RETURNING data_comment
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;

            $ret = $db.query(q:to/SQL/, $comment, $username, $!name, $var);
            INSERT INTO data_new (data_dataset, data_var, data_comment)
            VALUES (dataset_name2id($2,$3),$4,$1)
            RETURNING data_comment
            SQL
            $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method !store-instance-variable-comment($var, $instance, $comment) {

        return unless $var and $comment.defined and $instance;
        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $comment, $username, $!name, $var, $instance);
            UPDATE data_new SET data_comment = $1
             WHERE data_dataset=dataset_name2id($2,$3) AND data_var=$4
                                                       AND data_instance = $5
            RETURNING data_comment
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;

            $ret = $db.query(q:to/SQL/, $comment, $username, $!name, $var, $instance);
            INSERT INTO data_new (data_dataset, data_var, data_comment, data_instance)
            VALUES (dataset_name2id($2,$3),$4,$1,$5)
            RETURNING data_comment
            SQL
            $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method store-input-comment($var-name, $comment) {
        my $instance;

        my $var = $var-name;
        if $var ~~ s/\[(.+)\]/[]/ {
            $instance = $0;
        }

        return $instance ?? self!store-instance-variable-comment($var, $instance, $comment)
                         !! self!store-variable-comment($var, $comment);
    }

    method !store-variable($var, $value) {

        return unless $var and $value.defined;
        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $value, $username, $!name, $var);
            UPDATE data_new SET data_val = $1
             WHERE data_dataset=dataset_name2id($2,$3) AND data_var=$4
                                                       AND data_instance IS NULL
            RETURNING data_val
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;

            $ret = $db.query(q:to/SQL/, $value, $username, $!name, $var);
            INSERT INTO data_new (data_dataset, data_var, data_val)
            VALUES (dataset_name2id($2,$3),$4,$1)
            RETURNING data_val
            SQL
            $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method !store-instance-variable($var, $instance, $value) {

        return unless $var and $value.defined and $instance;
        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $value, $username, $!name, $var, $instance);
            UPDATE data_new SET data_val = $1
             WHERE data_dataset=dataset_name2id($2,$3) AND data_var=$4
                                                       AND data_instance = $5
            RETURNING data_comment
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;

            $ret = $db.query(q:to/SQL/, $value, $username, $!name, $var, $instance);
            INSERT INTO data_new (data_dataset, data_var, data_val, data_instance)
            VALUES (dataset_name2id($2,$3),$4,$1,$5)
            RETURNING data_comment
            SQL
            $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method store-input($var-name, $value) {
        my $instance;

        my $var = $var-name;
        if $var ~~ s/\[(.+)\]/[]/ {
            $instance = $0;
        }

        return $instance ?? self!store-instance-variable($var, $instance, $value)
                         !! self!store-variable($var, $value);
    }

    method !delete-variable($var) {

        return unless $var;
        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $username, $!name, $var);
            DELETE FROM data_new
             WHERE data_dataset=dataset_name2id($1,$2) AND data_var=$3
                                                       AND data_instance IS NULL
            RETURNING data_val
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method !delete-instance-variable($var, $instance) {

        return unless $var and $instance;
        my $username = $!user.username;

        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $username, $!name, $var, $instance);
            DELETE FROM data_new
             WHERE data_dataset=dataset_name2id($1,$2) AND data_var=$3
                                                       AND data_instance = $4
            RETURNING data_val
            SQL

            my $rows = $ret.rows;
            return $rows if $rows;
        }
    }

    method delete-input($var-name) {
        my $instance;

        my $var = $var-name;
        if $var ~~ s/\[(.+)\]/[]/ {
            $instance = $0;
        }

        return $instance ?? self!delete-instance-variable($var, $instance)
                         !! self!delete-variable($var);
    }

    method rename-instance($old-instance, $new-instance, $pattern) {
        self.with-db: -> $db {
            my $ret = $db.query(q:to/SQL/, $new-instance, $!id, "\%$pattern\%", $old-instance);
            UPDATE data_new set data_instance = $1
             WHERE data_dataset = $2
               AND data_var LIKE $3
               AND data_instance = $4
            RETURNING data_val
            SQL

            return $ret.rows;
        }
    }

    method order-instances(@instances) {
        warn "*** order-instance not yet implemented";
        self.with-db: -> $db {

            # my $i = 0;
            # for (@instances) {
            #     my $pattern  = $_;
            #     $pattern     =~ m/(.*)\[(.*)\]/;
            #     my $var      = $1;
            #     my $instance = $2;
            #     $var         = "%$var\[\]%";
            #     # warn "var=$var, instance=$instance";

            #     my $ret = $db.query(q:to/SQL/, $i, $!id, $var, $instance);
            #     UPDATE data_new SET data_instance_order = $1
            #      WHERE data_dataset = $2
            #       AND data_var      LIKE $3
            #       AND data_instance LIKE $4
            #     SQL
            #     $i++;
            # }
        }
        return True;
    }

}
