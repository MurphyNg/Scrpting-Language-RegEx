#!/usr/bin/perl
# Author: Yuhao Wu
# CGI Perl script

# makes CGI.pm treat all param() values as UTF-8 strings
use CGI qw(-utf8 :all *table);
use LWP::Simple qw(get);

# ensure that the web page is sent to the brower using UTF-8 encoding
binmode(STDOUT, ":encoding(utf-8)");
print header(-charset =>'utf-8'), "\n",
	  start_html ({- title =>'Code Analysis',
	      		   - author =>'rhaegar425@gmail.com'});

# the form generation session
print start_form({-method=>"POST",
                  -action=>"http://cgi.csc.liv.ac.uk/cgi-bin/cgiwrap/x7yw2/analysis.pl"});

# the textfield for entering a single URL
print h3("Input URL "), "\n";
print textfield({-name=>'URL',
			 	 -size=>150}), "\n", br();

# the textarea for entering a code snippet
print h3("Input Code"), "\n";
print textarea({-name =>'code',
				-rows => 10,
				-cols => 80}), br();

# the submit button for starting analysis
print br(), submit({-name =>'submit',
			  		-value =>'Submit'}), "\n";
print end_form;

# variables for storing the essential analysis items
@single_comments;
@multiline_comments;
$instruction_lines_num = 0;
$instruction_elements_num = 0;
$nonempty_comments_num = 0;
$non_trivial_comments_num = 0;
$comment_words_num = 0;
$comment_to_instruction_ratio = 0;
$nontrivial_comment_to_instruction_ratio = 0;
$comment_word_to_instruction_element_ratio = 0;

# listen for the submit button is clicked
if(param('submit')){

	# check if the user only enters content to either url textfield or the code textarea exactly 
	if((param('URL') && !param('code')) || (param('code') && !param('URL'))){

		# listen for the input entered into the URL textfield 
		if (param('URL')) {
				
			# validate the possible dangerous JavaScript code by the escapeHTML function
			$text = escapeHTML(get(param('URL')));

			# check if the code retrieval from the URL fails
			if(defined($text)){
				
				# the code entered is safe, regain the original code for later process
				$text = get(param('URL'));
				# statistically analyze the code
				analyze_code();

				# retrieval succeeds, show the original code snippet
				print h5("Content of ".param('URL')), "\n";
				print show_original_code_style(escapeHTML(get(param('URL'))));
				}else{ # error case: retrieval fails
					print h3("Error: nothing to retrieve, input a valid url again");	
				}

		# listen for the input entered into the code textarea 
		}elsif(param('code')){

			# validate the possible dangerous JavaScript code by the escapeHTML function
			$text = escapeHTML(param('code'));
				
				# check if the code is safe
				if(defined($text)){
				# the code entered is safe, regain the original code for later process
				$text = param('code');
				# statistically analyze the code
				analyze_code();

				print h5("Code you enter:"), "\n";
				print show_original_code_style(escapeHTML(param('code')));
			}else{ # error case: retrieval fails
					print h3("Error: nothing to retrieve, code is dangerous");	
			}

		}else{
			# error case: there is nothing from the input				
			print h3("Error: nothing to retrieve from your input");
		}

	}else{
		# error case: the user either enters neither URL nor code, or both of them
		print h3("Error: please ONLY submit either a URL or a code snippet, input again please")
	}	
}

# replace the \n by <br> in HTML
sub show_original_code_style{
	@_[0] =~ s/\n/<br>/g;
	return @_[0];
}

# main subroutine for statistically analyzing code and generate the result
sub analyze_code{
	@single_comments = get_single_comments($text);
	
	@multiline_comments = get_multiline_comments($text);
					 
	# the main 5 requried attributes to test				 
 	$nonempty_comments_num = count_nonempty_comments();
					
	$non_trivial_comments_num = count_nontrivial_comments();
										
	$comment_words_num = count_comment_words("@single_comments"."@multiline_comments");

	$instruction_lines_num = count_instruction_lines_num($text);
	
	$instruction_elements_num = count_elements(get_program_words($text));
	
	# create the analysis table for showing the result
	build_table();
}

# get all single-line comments in an array
sub get_single_comments{	
	return undef if(@_<1);
	push @single_lines, $1 while $_[0] =~ /((\/\/|\#).*(\w)+)/g ;	
	return @single_lines;
}


# count the number of single-line comments
sub count_single_line_comments{
	return 0 if(@_< 1);
	return scalar(@_);
}

# get all multi-line comments in an array
sub get_multiline_comments{
	return undef if(@_<1);
	push @multi_lines, $& while $_[0] =~ /\/\*(?:.|\n)*?\*\//g;
	return @multi_lines;
}

# count the number of multi-line comments by removing empty lines of comments
# input MUST be multi-line comments
sub count_multiline_comments{
	return 0 if(@_<1);
	my $counter = 0;
	foreach(@_){
		# use regex to find one-line comment with at least one Unicode word characters
		while(/^(.*(\p{L}|\p{N})+.*)$/gm){
			$counter++;
		} 
	}
	return $counter;
}

# count the sum of all non-empty comment
sub count_nonempty_comments{
	return count_single_line_comments(@single_comments)
			+ count_multiline_comments(@multiline_comments);
}

# count the number of comments with more than 5 Unicode word characters
sub count_non_trivial{		
	return 0 if(@_<1);
	my $counter = 0;
	my @non_trivial;

	foreach (@_) {	
	 	while(/\b\w+\b/g){		
	    		$counter++;
			}
		if($counter >= 5){			
			 push @non_trivial, $_;
			}
		$counter = 0;
	}
	return @non_trivial;
}

# count the sum of all comments with more than 5 Unicode word characters
sub count_nontrivial_comments{
	return scalar(count_non_trivial(@single_comments)) 
			+ scalar(count_non_trivial(@multiline_comments));
}

# count the sum of all words in all comments
sub count_comment_words{
	return 0 if(@_<1);
	my $words = 0;
	$_ = @_[0];
	print br();
	while(/\b\w+\b/g) {$words++;}
	return $words;
}

# remove the comments from the code
sub remove_comments{
	return undef if(@_<1);
	@_[0] =~ s/((\/\/|\#).*|\/\*(?:.|\n)*?\*\/)//g;
}

# count the sum of instrcution lines with at least one instruction element
sub count_instruction_lines_num{
	return 0 if(@_<1);
	remove_comments(@_[0]);
	# match instruction with at least one element
	push @single_line, $& while @_[0] =~ /^(.*(\b(?!\d)[a-zA-Z0-9_]+\b|[-\+\*\%\!\=\>\<\&\|])+.*)$/gm;
	return scalar(@single_line);
}

# spilt each of the program element
sub get_program_words{
	return undef if(@_<1);
	my @programe_words;
	push @programe_words, $& while @_[0] =~ /(\b(?!\d)[a-zA-Z0-9_]+\b|[-\+\*\%\!\=\>\<\&\|]+)/g;
	return @programe_words;
}
					
# count the number of all instruction element					
sub count_elements{
	return 0 if(@_<1);
    my $word_num = 0;
	for(@_){
		$word_num++;
	}						
	return $word_num;
}


# build the table for storing analysis result
sub build_table{
	print h4("Analysis"), "\n";
	print start_table ({- border => 2,
					    - width => '70%',
					    - align => 'center'});
	print caption ("Code Analysis");
	# table rows and columns	
	print Tr(td('Number of lines of instruction'), td($instruction_lines_num));
	print Tr(td('Number of elements of instruction'), td($instruction_elements_num));
	print Tr(td('Number of non-empty lines of comment'), td($nonempty_comments_num));
	print Tr(td('Number of non-trivial comments'), td($non_trivial_comments_num));
	print Tr(td('Number of words of comment'), td($comment_words_num));
	if($instruction_lines_num != 0){
		print Tr(td('Ratio of lines of comment to lines of instruction'), td(sprintf("%.1f", $nonempty_comments_num/$instruction_lines_num)));
		print Tr(td('Ratio of non-trivial comments to lines of instruction'), td(sprintf("%.1f", $non_trivial_comments_num/$instruction_lines_num)));
	}else{
		print Tr(td('Ratio of lines of comment to lines of instruction'), td("NAN"));
		print Tr(td('Ratio of non-trivial comments to lines of instruction'), td("NAN"));
	}
	if($instruction_elements_num != 0){
		print Tr(td('Ratio of words of comment to elements of instruction'), td( sprintf("%.1f", $comment_words_num/$instruction_elements_num)));
	}else{
		print Tr(td('Ratio of words of comment to elements of instruction'), td("NAN"));	
	}
	print end_table;
}

print end_html;