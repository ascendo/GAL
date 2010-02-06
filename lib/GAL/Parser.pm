package GAL::Parser;

use strict;
use vars qw($VERSION);


$VERSION = '0.01';
use base qw(GAL::Base);
use Text::RecordParser;

=head1 NAME

GAL::Parser - <One line description of module's purpose here>

=head1 VERSION

This document describes GAL::Parser version 0.01

=head1 SYNOPSIS

     use GAL::Parser;

=for author to fill in:
     Brief code example(s) here showing commonest usage(s).
     This section will be as far as many users bother reading
     so make it as educational and exemplary as possible.

=head1 DESCRIPTION

=for author to fill in:
     Write a full description of the module and its features here.
     Use subsections (=head2, =head3) as appropriate.


################################################################################
################################  TO DO ########################################
################################################################################

Maybe allow using using any file iterator
Maybe remove Text::RecordParser
Maybe allow using any feature_factory

################################################################################
################################################################################
################################################################################

=head1 METHODS

=cut

#-----------------------------------------------------------------------------

=head2 new

     Title   : new
     Usage   : GAL::Parser->new();
     Function: Creates a GAL::Parser object;
     Returns : A GAL::Parser object
     Args    :

=cut

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	return $self;
}

#-----------------------------------------------------------------------------

sub _initialize_args {
	my ($self, @args) = @_;

	my $args = $self->SUPER::_initialize_args(@args);

	my @valid_attributes = qw(file
                                  fh
				  record_separator
				  field_separator
				  comment_delimiter
				  fields
				 );

	$self->set_attributes($args, @valid_attributes);

	return $args;

}

#-----------------------------------------------------------------------------

=head2 file

 Title   : file
 Usage   : $a = $self->file();
 Function: Get/Set the value of file.
 Returns : The value of file.
 Args    : A value to set file to.

=cut

sub file {
	my ($self, $value) = @_;
	$self->{file} = $value if defined $value;
	return $self->{file};
}

#-----------------------------------------------------------------------------

=head2 fh

 Title   : fh
 Usage   : $a = $self->fh();
 Function: Get/Set the filehandle.
 Returns : The filehandle.
 Args    : A filehandle.

=cut

sub fh {
	my ($self, $value) = @_;
	$self->{fh} = $value if defined $value;
	return $self->{fh};
}

#-----------------------------------------------------------------------------

=head2 parser

 Title   : parser
 Usage   : $a = $self->parser();
 Function: Get/Set the parser.  This is left as a public
	   method to support future use of alternate parsers, but
	   this is currently not implimented so this method should be
	   considered for internal use only.
 Returns : The value of parser.
 Args    : A value to set parser to.

=cut

sub parser {
	my ($self, $value) = @_;
	$self->{parser} = $value if defined $value;
	if (! $self->{parser}) {
		if (! $self->file && ! $self->fh) {
			$self->throw('Tried to create a ' . ref $self . 'without a file or filehandle to parse');
		}
		my $parser;
		if ($self->{fh}) {
			$parser = Text::RecordParser->new({fh               => $self->fh,
							   record_separator => $self->record_separator,
							   field_separator  => $self->field_separator,
							   comment          => $self->comment_delimiter,
							  });
		}
		else {
			$parser = Text::RecordParser->new({filename         => $self->file,
							   record_separator => $self->record_separator,
							   field_separator  => $self->field_separator,
							   comment          => $self->comment_delimiter,
							  });
		}
		$parser->bind_fields($self->fields);
		$self->{parser} = $parser;
	}

	return $self->{parser};
}

#-----------------------------------------------------------------------------

=head2 _read_next_record

 Title   : _read_next_record
 Usage   : $a = $self->_read_next_record();
 Function: Return the next record from the parser
 Returns : The next record from the parser.
 Args    : N/A

=cut

sub _read_next_record {
	my $self = shift;
	return $self->parser->fetchrow_hashref;
}

#-----------------------------------------------------------------------------

=head2 next_feature_hash

 Title   : next_feature_hash
 Usage   : $a = $self->next_feature_hash;
 Function: Return the next record from the parser as a 'feature hash'.
 Returns : A hash or hash reference.
 Args    : N/A

=cut

sub next_feature_hash {
	my $self = shift;

	my $feature;

	# If a previous record has returned multiple features then 
	# grab them off the stack first instead of reading a new one
	# from the file.
	if (ref $self->{_feature_stack} eq 'ARRAY' &&
	    scalar @{$self->{_feature_stack}} > 0) {
		$feature = shift @{$self->{_feature_stack}};
		return wantarray ? %{$feature} : $feature;
	}

	until ($feature) {
		# Get the next record from the file.
		my $record = $self->_read_next_record;
		return undef if ! defined $record;

		# Parser the record - probably overridden by a subclass.
		$feature = $self->parse_record($record);
	}

	# Allow parsers to return more than one feature.
	# This allows the parser to expand a single record into
	# multiple features.
	if (ref $feature eq 'ARRAY') {
		my $this_feature = shift @{$feature};
		push @{$self->{_feature_stack}}, @{$feature};
		$feature = $this_feature;
	}

	return wantarray ? %{$feature} : $feature;
}

#-----------------------------------------------------------------------------

=head2  to_gff3

 Title   : to_gff3
 Usage   : $self->to_gff3($feature_hash)
 Function: Returns a string of GFF3 formatted text for a given feature hash
 Returns : A string in GFF3 format.
 Args    : A feature hash reference in the form returned by next_feature_hash

=cut

sub to_gff3 {
	my ($self, $feature) = @_;

	my $attrb_text;

	my $gff3_text = join "\t", ($feature->{seqid},
				    $feature->{source},
				    $feature->{type},
				    $feature->{start},
				    $feature->{end},
				    $feature->{score},
				    $feature->{strand},
				    $feature->{phase},
				   );

	my $att_text = 'ID=' . $feature->{feature_id} . ';';
	if ($feature->{attributes}{Parent}) {
		my @parents = @{$feature->{attributes}{Parent}};
		$att_text .= 'Parent=' . join ',', @parents . ';';
	}
	if ($feature->{attributes}{Name}[0]) {
		my $name_text = join ',', @{$feature->{attributes}{Name}};
		$att_text .= "Name=$name_text;";
	}
	for my $tag (keys %{$feature->{attributes}}) {
		next if $tag =~ /^(ID|Parent|Name)$/;
		my @values = @{$feature->{attributes}{$tag}};
		my $value_text = '';
		if (scalar @values) {
			$value_text = join ',', @values;
		}
		$att_text .= "$tag=$value_text;";
	}
	$gff3_text .= "\t$att_text\n";

	return $gff3_text;
}

#-----------------------------------------------------------------------------

=head2 record_separator

 Title   : record_separator
 Usage   : $a = $self->record_separator();
 Function: Get/Set the value of record_separator.
 Returns : The value of record_separator.
 Args    : A value to set record_separator to.

=cut

sub record_separator {
	my ($self, $value) = @_;
	$self->{record_separator} = $value if defined $value;
	$self->{record_separator} ||= "\n";
	return $self->{record_separator};
}

#-----------------------------------------------------------------------------

=head2 field_separator

 Title   : field_separator
 Usage   : $a = $self->field_separator();
 Function: Get/Set the value of field_separator.
 Returns : The value of field_separator.
 Args    : A value to set field_separator to.

=cut

sub field_separator {
	my ($self, $value) = @_;
	$self->{field_separator} = $value if defined $value;
	$self->{field_separator} ||= "\t";
	return $self->{field_separator};
}

#-----------------------------------------------------------------------------

=head2 comment_delimiter

 Title   : comment_delimiter
 Usage   : $a = $self->comment_delimiter();
 Function: Get/Set the value of comment_delimiter.
 Returns : The value of comment_delimiter.
 Args    : A value to set comment_delimiter to.

=cut

sub comment_delimiter {
	my ($self, $value) = @_;
	$self->{comment_delimiter} = $value if defined $value;
	$self->{comment_delimiter} ||= qr/^\#/;
	return $self->{comment_delimiter};
}

#-----------------------------------------------------------------------------

=head2 fields

 Title   : fields
 Usage   : $a = $self->fields();
 Function: Get/Set the value of fields.
 Returns : The value of fields.
 Args    : A value to set fields to.

=cut

sub fields {
	my ($self, $value) = @_;
	$self->{fields} = $value if defined $value;
	$self->{fields} ||= [qw(seqid source type start end score strand phase attributes)];
	return wantarray ? @{$self->{fields}} : $self->{fields};
}

#-----------------------------------------------------------------------------

=head2 parse_record

 Title   : parse_record
 Usage   : $a = $self->parse_record();
 Function: Parse the data from a record.
 Returns : A hash ref needed by Feature.pm to create a Feature object
 Args    : A hash ref of fields that this sub can understand (In this case GFF3).

=cut

sub parse_record {
	my ($self, $record) = @_;

	my $attributes = $self->parse_attributes($record->{attributes});

	my $feature_id = $record->{attributes}{id} || join ':',
	  @{$record}{qw(seqid source type start end)};

	my $feature_hash = {feature_id => $feature_id,
			    seqid      => $record->{seqid},
			    source     => $record->{source},
			    type       => $record->{type},
			    start      => $record->{start},
			    end        => $record->{end},
			    score      => $record->{score},
			    strand     => $record->{strand},
			    phase      => $record->{phase},
			    attributes => $attributes,
			   };

	return $feature_hash;
}

#-----------------------------------------------------------------------------

=head2 parse_attributes

 Title   : parse_attributes
 Usage   : $a = $self->parse_attributes($attrb_text);
 Function: Parse the attributes from column 9 in a GFF3 style file.
 Returns : The value of parse_attributes.
 Args    : A value to set parse_attributes to.

=cut

sub parse_attributes {
	my ($self, $attrb_text) = @_;

	my @attrbs = split /\s*;\s*/, $attrb_text;
	my %attrb_hash;
	for my $attrb (@attrbs) {
		my ($tag, $value_text) = split /=/, $attrb;
		my @values = split /,/, $value_text;
		push @{$attrb_hash{$tag}}, @values;
	}
	return \%attrb_hash;
}



#-----------------------------------------------------------------------------

=head2 get_genotype

 Title   : get_genotype
 Usage   : $a = $self->get_genotype($reference_allele, \@variant_alleles);
 Function: Determine the genotype.
 Returns : A genotype name
 Args    : The reference allele and an array reference of variant alleles.

=cut

sub get_genotype {
	my ($self, $reference_allele, $variant_alleles) = @_;

	my $variant_count = scalar @{$variant_alleles};

	if ($variant_count == 1) {
		if ($variant_alleles->[0] ne $reference_allele) {
			return 'homozygous';
		}
		else {
			self->warn(message => 'You appear to have a variant that is homozygous for the reference allele:');
		}
	}
	elsif ($variant_count > 1) {
		if (grep {$_ eq $reference_allele} @{$variant_alleles}) {
			return 'heterozygous:with_reference_allele';
		}
		else {
			return 'heterozygous:no_reference_allele';
		}
	}

	$self->throw(message => ("Uncaught combination ref:$reference_allele vars:" .
				 join(q{,}, @{$variant_alleles}) .
				 ' in GAL::Parser::get_genotype!'));
}

#-----------------------------------------------------------------------------

=head1 DIAGNOSTICS

=for author to fill in:
     List every single error and warning message that the module can
     generate (even the ones that will "never happen"), with a full
     explanation of each problem, one or more likely causes, and any
     suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back

=head1 CONFIGURATION AND ENVIRONMENT

<GAL::Parser> requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to:
barry.moore@genetics.utah.edu

=head1 AUTHOR

Barry Moore <barry.moore@genetics.utah.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Barry Moore <barry.moore@genetics.utah.edu>.  All rights reserved.

    This module is free software; you can redistribute it and/or
    modify it under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;

__END__

=head2 get_all_features

 Title   : get_all_features
 Alias   : get_features
 Usage   : $features = $self->get_all_features();
 Function: Get all the features objects created by this parser.
 Returns : A list of Feature objects.
 Args    : N/A

=cut


#sub get_all_features {
#	my $self = shift;
#	$self->_parse_all_features unless $self->{features};
#	return wantarray ? @{$self->{features}} : $self->{features};
#}

=head2 get_features

 Alias for get_all_features

=cut

#sub get_features {shift->get_all_features(@_)}

#-----------------------------------------------------------------------------

=head2 _parse_all_features

 Title   : _parse_all_features
 Alias   : parse # Depricated but kept for backwards compatibility
 Usage   : $a = $self->_parse_all_features();
 Function: Parse and store all of the features in a file
 Returns : N/A
 Args    : N/A

=cut

#sub _parse_all_features {
#
#	my $self = shift;
#
#	while (my $record = $self->_read_next_record) {
#
#		my $feature_hash = $self->parse_record($record);
#		next unless defined $feature_hash;
#		my $type = $feature_hash->{type};
#		my $feature = $self->feature_factory->create($feature_hash);
#		push @{$self->{features}}, $feature;
#
#	}
#	return $self;
#}

=head2 parse

 Depricated alias for _parse_all_features

=cut

#sub parse {
#	my $self = shift;
#	$self->warn(message => ("The method GAL::Parser::parse is " .
#				"depricated.  Please use " .
#				"GAL::Parser::_parse_all_features " .
#				"instead.")
#		   );
#	return $self->_parse_all_features(@_);
#}

#-----------------------------------------------------------------------------

=head2 parse_next_feature

 Title   : parse_next_feature
 Alias   : next_feature
 Alias   : get_next_feature
 Usage   : $a = $self->parse_next_feature();
 Function: Get/Set the value of parse.
 Returns : The value of parse.
 Args    : A value to set parse to.

=cut

#sub parse_next_feature {
#
#	my $self = shift;
#
#	my $feature_hash;
#	until (defined $feature_hash) {
#		my $record = $self->_read_next_record;
#		last unless $record;
#
#		$feature_hash = $self->parse_record($record);
#	}
#	return undef unless defined $feature_hash;
#
#	my $type = $feature_hash->{type};
#	my $feature = $self->feature_factory->create($feature_hash);
#
#	return $feature;
#}

=head2 next_feature

 Alias for parse_next_feature

=cut

#sub next_feature     {shift->parse_next_feature(@_)}

=head2 get_next_feature

 Alias for parse_next_feature

=cut

#sub get_next_feature {shift->parse_next_feature(@_)}

#-----------------------------------------------------------------------------