role Agrammon::DB {
    method connection() { $*AGRAMMON-DB-CONNECTION }

    method with-db(&operation) {
        with $*AGRAMMON-DB-HANDLE {
            operation($*AGRAMMON-DB-HANDLE);
        }
        else {
            self!with-fresh-handle(&operation);
        }
    }

    method !with-fresh-handle(&operation) {
        my $handle = self.connection.db;
        my $*AGRAMMON-DB-HANDLE = $handle;
        my \result := operation($handle);
        $handle.finish;
        return result;
        CATCH {
            .finish with $handle;
        }
    }
}
