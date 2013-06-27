#!/usr/bin/perl

# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2013  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use utf8;
use Test::Spec 0.46;
use Test::Deep;
use FindBin;
use lib "$FindBin::RealBin/../", "$FindBin::RealBin/../../lib";
use App::MtAws::Journal;
use File::Path;
use POSIX;
use TestUtils;
use POSIX;
use Time::Local;
use Carp;
use App::MtAws::MetaData;
use App::MtAws::DownloadInventoryCommand;
use File::Temp ();
use Data::Dumper;
require App::MtAws::SyncCommand;

warning_fatal();

describe "command" => sub {
	describe "run" => sub {
		my $j;
		
		before each => sub {
			$j = App::MtAws::Journal->new(journal_file => 'x', 'root_dir' => 'x' );
		};
		
		sub expect_with_forks
		{
			App::MtAws::SyncCommand->expects("with_forks")->returns_ordered(sub{
				my ($flag, $options, $cb) = @_;
				is $flag, !$options->{'dry-run'};
				is $options, $options;
				$cb->();
			});
		}
		
		sub expect_journal_init
		{
			my ($options, $read_files_mode) = @_;
			App::MtAws::Journal->expects("read_journal")->with(should_exist => 0)->returns_ordered->once;#returns(sub{ is ++shift->{_stage}, 1 })
			App::MtAws::Journal->expects("read_files")->returns_ordered(sub {
				shift;
				cmp_deeply [@_], [$read_files_mode, $options->{'max-number-of-files'}];
			})->once;
			App::MtAws::Journal->expects("open_for_write")->returns_ordered->once;
		}
		
		sub expect_fork_engine
		{
			App::MtAws::SyncCommand->expects("fork_engine")->returns_ordered(sub {
				bless { parent_worker =>
					bless {}, 'App::MtAws::ParentWorker'
				}, 'App::MtAws::ForkEngine';
			})->once;
		}
		
		sub expect_journal_close
		{
			App::MtAws::Journal->expects("close_for_write")->returns_ordered->once;
		}
		
		sub expect_process_task
		{
			my ($j, $cb) = @_;
			App::MtAws::ParentWorker->expects("process_task")->returns_ordered(sub {
				my ($self, $job, $journal) = @_;
				ok $self->isa('App::MtAws::ParentWorker');
				is $journal, $j;
				$cb->($job);
			} )->once;
		}
		
		it "should work with new" => sub {
			my $options = { 'max-number-of-files' => 10, partsize => 2, new => 1 };
			ordered_test sub {
				expect_with_forks;
				expect_journal_init($options, {new=>1});
				expect_fork_engine;
				my @files = qw/file1 file2 file3 file4/;
	
				expect_process_task($j, sub {
					my ($job) = @_;
					ok $job->isa('App::MtAws::JobListProxy');
					is scalar @{ $job->{jobs} }, 1;
					my $itt = $job->{jobs}[0];
					for (@files) {
						my $task = $itt->{iterator}->();
						is $task->{job}{relfilename}, $_;
						is $task->{job}{partsize}, $options->{partsize}*1024*1024;
						ok $task->isa('App::MtAws::JobProxy');
						ok $task->{job}->isa('App::MtAws::FileCreateJob');
					}
					return (1)
				});
	
				expect_journal_close;
				$j->{listing}{existing} = [];
				$j->{listing}{new} = [ map { { relfilename => $_ }} @files ];
				
				App::MtAws::SyncCommand::run($options, $j);
			};
		};
		
		it "should work with replace-modified" => sub {
			my $options = { 'max-number-of-files' => 10, partsize => 2, 'replace-modified' => 1, detect => 'mtime-and-treehash' };
			ordered_test sub {
				expect_with_forks;
				expect_journal_init($options, {existing=>1});
				expect_fork_engine;
				my %files = (
					file1 => {size => 123},
					file2 => {size => 456},
					file3 => {size => 789},
					file4 => {size => 42}
				);
	
				expect_process_task($j, sub {
					my ($job) = @_;
					ok $job->isa('App::MtAws::JobListProxy');
					is scalar @{ $job->{jobs} }, 1;
					my $itt = $job->{jobs}[0];
					for (sort keys %files) {
						my $task = $itt->{iterator}->();
						is $task->{job}{relfilename}, $_;
						is $task->{job}{partsize}, $options->{partsize}*1024*1024;
						ok $task->isa('App::MtAws::JobProxy');
						ok $task->{job}->isa('App::MtAws::FileCreateJob');
					}
					return (1)
				});
	
				expect_journal_close;
				$j->{listing}{new} = [];
				for (sort keys %files) {
					my $r = {relfilename => $_, size => $files{$_}{size}};
					$j->_add_filename($r);
					push @{ $j->{listing}{existing} }, $r;
				}
				App::MtAws::SyncCommand->expects("file_size")->returns(sub {
					my ($file) = @_;
					$file =~ m!([^/]+)$! or confess;
					$files{$1}{size}+1 or confess;
				})->exactly(scalar keys %files);
				
				App::MtAws::SyncCommand::run($options, $j);
			};
		};
	}
};

runtests unless caller;

1;
