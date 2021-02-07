use v6;

use Cro::HTTP::Router;
use Cro::OpenAPI::RoutesFromDefinition;

use Agrammon::DB::User;
use Agrammon::Web::Service;
use Agrammon::Web::SessionUser;

subset LoggedIn of Agrammon::Web::SessionUser where .logged-in;


sub routes(Agrammon::Web::Service $ws) is export {

    # Fix for Agrammon
    # my $root = $app ~~ Agrammon::Application::Development ?? 'frontend/source-output' !! 'qx-build';
    my $schema = 'share/agrammon.openapi';
    my $root = '';
    route {
        if %*ENV<AGRAMMON_DEBUG> {
            before {
                # Consume and re-instate request.
                my $blob = await request.body-blob;
                request.set-body($blob);
                # Dump.
                my $req = ~request;
                try $req ~= $blob.decode('utf-8');
                note $req;
            }
        }
        include static-content($root);
        include api-routes($schema, $ws);
        include dataset-routes($ws);
        include application-routes($ws);
        after {
            forbidden if .status == 401 && request.auth.logged-in;
            .status = 401 if .status == 418;
        }
    }
}

sub static-content($root) {
    route {
        my $root = %*ENV<SOURCE_MODE> ?? 'frontend/compiled/source' !! 'public';

        if %*ENV<SOURCE_MODE> { # Qooxdoo source mode (development)
            get -> {
                static "$root/agrammon/index.html"
            }
            get -> 'index.html' {
                static "$root/agrammon/index.html"
            }
            get -> 'index.js' {
                static "$root/agrammon/index.js"
            }
            get -> 'favicon.ico' {
                static "$root/resource/agrammon/favicon.ico"
            }

            get -> 'transpiled', *@path {
                static "$root/transpiled", @path
            }

            get -> 'resource', *@path {
                static "$root/resource", @path
            }

            get -> 'media/psf/Home/checkouts/agrammon6/frontend', *@path {
                static "frontend", @path
            }

            # catch all
            get -> *@path {
                static "$root/agrammon", @path
            }

        }
        else { # Qooxdoo build mode (production)
            get -> {
                static "$root/index.html"
            }

            get -> 'index.html' {
                static "$root/index.html"
            }

            get -> 'favicon.ico' {
                static "$root/resource/Agrammon/favicon.ico"
            }

            get -> 'agrammon', *@path {
                static "$root/agrammon", @path
            }

            get -> 'resource', *@path {
                static "$root/resource", @path
            }
        }


# TODO: needs later fixing
#        get -> 'QxJqPlot/source/resource', *@path {
#            static $root ~ 'static/resource', @path
#        }

    }
}

sub api-routes (Str $schema, $ws) {
    openapi $schema.IO, {
        # working
        operation 'createAccount', -> LoggedIn $user {
            request-body -> (:$email!, :$password!, :$key, :$firstname, :$lastname, :$org, :$role) {
                my $username = $ws.create-account($user, $email, $password, $key, $firstname, $lastname, $org, $role);
                content 'application/json', { :$username };
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::User::CreateFailed  {
                        not-found 'application/json', %( error => .message );
                    }
                    when X::Agrammon::DB::User::AlreadyExists
                       | X::Agrammon::DB::User::CreateFailed  {
                        conflict 'application/json', %( error => .message );
                    }
                    when X::Agrammon::DB::User::NoUsername {
                        bad-request 'application/json', %( error => .message );
                    }
                    when X::Agrammon::DB::User::UnknownRole  {
                        response.status = 422;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'cloneDataset', -> LoggedIn $user {
            request-body -> ( :newUsername($new-username),
                              :oldDataset($old-dataset), :newDataset($new-dataset)  ) {
                $ws.clone-dataset($user, $new-username, $old-dataset, $new-dataset);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::AlreadyExists {
                        conflict 'application/json', %( error => .message );
                    }
                    when X::Agrammon::DB::Dataset::CloneFailed {
                        response.status = 500;
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'renameDataset', -> LoggedIn $user {
            request-body -> ( :oldName($old-name), :newName($new-name) ) {
                $ws.rename-dataset($user, $old-name, $new-name);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::AlreadyExists | X::Agrammon::DB::Dataset::RenameFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'createTag', -> LoggedIn $user {
            request-body -> ( :$name ) {
                $ws.create-tag($user, $name);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Tag::AlreadyExists | X::Agrammon::DB::Tag::CreateFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'deleteTag', -> LoggedIn $user {
            request-body -> ( :$name ) {
                $ws.delete-tag($user, $name);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Tag::DeleteFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'renameTag', -> LoggedIn $user {
            request-body -> ( :oldName($old-name), :newName($new-name) ) {
                $ws.rename-tag($user, $old-name, $new-name);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Tag::AlreadyExists | X::Agrammon::DB::Tag::RenameFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'renameInstance', -> LoggedIn $user {
            request-body -> ( :datasetName($dataset-name), :oldName($old-name), :newName($new-name), :variablePattern($variable-pattern)! ) {
                $ws.rename-instance($user, $dataset-name, $old-name, $new-name, $variable-pattern);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::InstanceAlreadyExists | X::Agrammon::DB::Dataset::InstanceRenameFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'orderInstances', -> LoggedIn $user {
            request-body -> (:datasetName($dataset-name)!, :@instances!) {
                $ws.order-instances($user, $dataset-name, @instances);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::InstanceReorderFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'deleteInstance', -> LoggedIn $user {
            request-body -> ( :datasetName($dataset-name), :$instance, :variablePattern($variable-pattern) ) {
                $ws.delete-instance($user, $dataset-name, $variable-pattern, $instance);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::InstanceDeleteFailed {
                        conflict 'application/json', %( error => .message );
                    }
                }
            }
        }
        operation 'changePassword', -> LoggedIn $user {
            request-body -> (:oldPassword($old-password)!, :newPassword($new-password)!) {
                $ws.change-password($user, $old-password, $new-password);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::User::PasswordsIdentical {
                        conflict 'application/json', %( error => .message );
                    }
                    when X::Agrammon::DB::User::InvalidPassword {
                        response.status = 422;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        # TODO: test from login screen
        operation 'resetPassword', -> LoggedIn $user {
            request-body -> (:$email!, :$password!, :$key!) {
                $ws.reset-password($email, $password, $key);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::User::PasswordResetFailed {
                        conflict 'application/json', %( error => .message );
                    }
                 }
            }
        }
        operation 'storeInputComment', -> LoggedIn $user {
            request-body -> ( :datasetName($dataset-name), :$variable, :$comment ) {
                $ws.store-input-comment($user, $dataset-name, $variable, $comment);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::StoreInputCommentFailed {
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'storeData', -> LoggedIn $user {
            request-body -> ( :datasetName($dataset-name), :$variable, :$value, :@branches, :@options , Int :$row) {
                $ws.store-data(
                    $user, $dataset-name, $variable, $value, @branches, @options, $row
                );
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::StoreDataFailed {
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'setTag', -> LoggedIn $user {
            request-body -> ( :@datasets!, :tagName($tag-name)! ) {
                $ws.set-tag($user, @datasets, $tag-name);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::SetTagFailed {
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'removeTag', -> LoggedIn $user {
            request-body -> ( :@datasets!, :tagName($tag-name)! ) {
                $ws.remove-tag($user, @datasets, $tag-name);
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::Dataset::RemoveTagFailed {
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'exportExcel', -> LoggedIn $user {
            request-body -> %params {
                response.append-header(
                    'Content-disposition',
                    # prevent header injection
                    "attachment; filename=%params<datasetName>.subst(/<-[\w_.-]>/, '', :g).xlsx"
                );
                content 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    $ws.get-excel-export($user, %params).to-blob;
                 CATCH {
                    default {
                        note "$_";
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'exportPDF', -> LoggedIn $user {
            request-body -> %params {
                response.append-header(
                    'Content-disposition',
                    # prevent header injection
                    "attachment; filename=%params<datasetName>.subst(/<-[\w_.-]>/, '', :g).pdf"
                    );
                content 'application/pdf',
                        $ws.get-pdf-export($user, %params);
                CATCH {
                    default {
                        note "$_";
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'getOutputVariables', -> LoggedIn $user {
            request-body -> ( :datasetName($dataset-name)! ) {
                my %output = $ws.get-output-variables($user, $dataset-name);
                content 'application/json', { %output };
                CATCH {
                    default {
                        note "$_";
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
        operation 'getInputVariables', -> LoggedIn $user {
            request-body -> ( :datasetName($dataset-name)! ) {
                my %data = $ws.get-input-variables;
                %data<datasetName> = $dataset-name;
                content 'application/json', %data;
                CATCH {
                    default {
                        note "$_";
                        response.status = 500;
                        content 'application/json', %( error => .message )
                    }
                }
            }
        }
    }
}

sub dataset-routes(Agrammon::Web::Service $ws) {
    route {
        # working
        post -> LoggedIn $user, 'get_datasets' {
            my $cfg = $ws.cfg;
            my $model-version = $cfg.app-variant; # model 'SingleSHL';

            my $data = $ws.get-datasets($user, $model-version);
            content 'application/json', $data;
        }

        # working
        post -> LoggedIn $user, 'delete_datasets' {
            request-body -> (:@datasets!) {
                my $deleted = $ws.delete-datasets($user, @datasets);
                content 'application/json', { :$deleted } ;
            }
        }

        # working
        post -> LoggedIn $user, 'create_dataset' {
            request-body -> (:$name!) {
                my $dataset-name = $ws.create-dataset($user, $name);
                content 'application/json', { :name($dataset-name) };
            }
        }

        # working
        post -> LoggedIn $user, 'load_dataset' {
            request-body -> (:name($dataset)!) {
                my @data = $ws.load-dataset($user, $dataset);
                content 'application/json', @data;
            }
        }

        # working
        post -> LoggedIn $user, 'store_dataset_comment' {
            request-body -> (:dataset($dataset-name)!, :$comment!) {
                my $ret = $ws.store-dataset-comment($user, $dataset-name, $comment);
                content 'application/json', %( :stored($ret) );
            }
        }

        # working
        post -> LoggedIn $user, 'get_tags' {
            my $data = $ws.get-tags($user);
            content 'application/json', $data;
        }

        post -> LoggedIn $user, 'send_datasets' {
            request-body -> (:@datasets!, :$recipient!, :$language = 'de') {
                my $data = $ws.send-datasets($user, @datasets, $recipient, $language);
                content 'application/json', $data;
                CATCH {
                    note "Routes: $_";
                    when X::Agrammon::DB::User::UnknownUser {
                        conflict 'application/json', %( error => .message );
                    }
                    default {
                        note "send_datasets route: $_";
                    }
                }
            }
        }

        # TODO: implement/test submit_dataset()
        post -> LoggedIn $user, 'submit_dataset' {
            request-body -> %params {
                my $data = $ws.submit-dataset($user, %params);
                content 'application/json', $data;
            }
        }
   }
}

sub application-routes(Agrammon::Web::Service $ws) {
    route {
        # working
        post -> 'get_cfg' {
            my %cfg = $ws.get-cfg;
            content 'application/json', %cfg;
        }

        post -> Agrammon::Web::SessionUser $user, 'logout' {
            $user.logout();
            content 'application/json', %(
                user       => $user.username,
                sudoUser   => 0
            );
        }

        # TODO: implement news in auth()
        post -> Agrammon::Web::SessionUser $user, 'auth' {
            request-body -> %data {
                my $username = %data<user>;
                my $password = %data<password>;
                if $user.auth($username, $password) {
                    content 'application/json', %(
                        user       => $username,
                        role       => $user.role.name,
                        last_login => $user.last-login,
                        news       => Nil,
                        sudoUser   => 0
                    );
                }
                CATCH {
                    note "$_";
                    when X::Agrammon::DB::User::InvalidPassword  {
                        forbidden 'application/json', %( error => .message );
                    }
                }
            }
        }

        # TODO: test/implement load_branch_data()
        post -> LoggedIn $user, 'load_branch_data' {
            request-body -> (:$name!) {
                my $data = $ws.load-branch-data($user, $name);
                content 'application/json', $data;
            }
        }

        # TODO: test/implement store_branch_data()
        post -> LoggedIn $user, 'store_branch_data' {
            request-body -> (:datasetName($dataset-name)!, :%data!) {
                my $data = $ws.store-branch-data($user, %data, $dataset-name);
                content 'application/json', $data;
            }
        }

    }
}
