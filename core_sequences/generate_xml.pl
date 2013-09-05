#!/usr/bin/env perl

my $species = $g_dbh->selectall_arrayref(qq{
    SELECT id, code, name, organism
    FROM species
});

my $families = $g_dbh->selectall_hashref(
    qq{
        SELECT id, code, name, level
        FROM families
    }, 'id'
);


my $query = qq{
    SELECT
        sequences.id,
        sequences.name,
        sequences.annotation,
        GROUP_CONCAT(family_id) AS family_ids
    FROM
        sequences
        JOIN families_sequences ON sequences.id = sequence_id
    WHERE
        species_id = ?
    GROUP BY sequences.id
}

foreach (@$species) {
    my $sequences = $g_dbh->selectall_arrayref( $query, { Slice => {} }, $_->{'id'} );
    my $fh;
    open( $fh, '>', $_->{'code'} . '.xml' )
        or die "Can't open > $_->{'code'}.xml : $!";
    map{ print $fh xml_doc($_) } @$sequences;
    close $fh;
}

sub xml_doc
{
    my ($species, $sequence) = @_;
    
    my $fields = qq{
      <field name="id">$sequence->{'id'}</field>
      <field name="name">$sequence->{'name'}</field>
      <field name="species_code">$species->{'code'}</field>
      <field name="species_name">$species->{'name'}</field>
      <field name="organism">$species->{'organism'}</field>
    };
    
    foreach my $family_id (split(',', $sequence->{'family_ids'})) {
        my $family = $families->{$family_id};
        my $code  = $family->{'code'};
        my $name  = $family->{'name'};
        my $level = $family->{'level'};
        
        $fields .= qq{
            <field name="family_$level">$code $name</field>
        };
    }
    
    my $dbxref_list = $g_dbh->selectall_arrayref(
        qq{
            SELECT
                db_id,
                CONCAT(accession, description) AS desc
            FROM
                dbxref
                JOIN dbxref_sequences ON dbxref_id = dbxref.id
            WHERE
                db_id IN (2, 3)
                sequence_id = ?
        }, { Slice => {} }, $sequence->{'id'}
    );
    
    foreach my $dbxref (@$dbxref_list) {
        if( $db_id == 2 ) {
            $fields .= qq{
                <field name="uniprot">$dbxref->{'desc'}</field>
            }
        }
        elsif( $db_id == 3 ) {
            $fields .= qq{
                <field name="pubmed">$dbxref->{'desc'}</field>
            }
        }
    }
    
    my $go_list = $g_dbh->selectall_arrayref(
        qq{
            SELECT CONCAT(code, description) AS desc
            FROM
                go
                JOIN go_sequences_cache ON go_id = go.id
            WHERE
                sequence_id = ?
        }, { Slice => {} }, $sequence->{'id'}
    );
    map{
        $fields .= qq{
            <field name="go">$_->{'desc'}</field>
        }
    } @$go_list;
    
    my $ipr_list = $g_dbh->selectall_arrayref(
        qq{
            SELECT CONCAT(code, description) AS desc
            FROM
                ipr
                JOIN ipr_sequences ON ipr_id = ipr.id
            WHERE
                sequence_id = ?
        }, { Slice => {} }, $sequence->{'id'}
    );
    map{
        $fields .= qq{
            <field name="interpro">$_->{'desc'}</field>
        }
    } @$ipr_list;
    
    return qq{
        <doc>
            $fields
        </doc>
    };
}
