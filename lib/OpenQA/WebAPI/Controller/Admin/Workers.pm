# Copyright (C) 2015 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package OpenQA::WebAPI::Controller::Admin::Workers;
use Mojo::Base 'Mojolicious::Controller';
use OpenQA::Utils;
use OpenQA::ServerSideDataTable;
use Scalar::Util 'looks_like_number';

sub _extend_info {
    my ($w) = @_;
    my $info = $w->info;
    $info->{name}      = $w->name;
    $info->{t_updated} = $w->t_updated;
    return $info;
}

sub index {
    my ($self) = @_;

    my $workers = $self->db->resultset('Workers');
    my %workers;
    while (my $w = $workers->next) {
        next unless $w->id;
        $workers{$w->name} = _extend_info($w);
    }
    $self->stash(workers => \%workers);

    $self->render('admin/workers/index');
}

sub show {
    my ($self) = @_;

    my $w = $self->db->resultset('Workers')->find($self->param('worker_id'))
      or return $self->reply->not_found;
    $self->stash(worker => _extend_info($w));

    $self->render('admin/workers/show');
}

sub previous_jobs_ajax {
    my ($self) = @_;

    OpenQA::ServerSideDataTable::render_response(
        controller            => $self,
        resultset             => 'Jobs',
        columns               => [qw(id result t_finished)],
        initial_conds         => [{assigned_worker_id => $self->param('worker_id')}],
        additional_params     => {prefetch => [qw(children parents)]},
        prepare_data_function => sub {
            my ($results) = @_;
            my @jobs = $results->all;
            my @ids = map { $_->id } @jobs;
            my $stats = OpenQA::Schema::Result::JobModules::job_module_stats(\@ids);
            my @data;
            for my $job (@jobs) {
                push(
                    @data,
                    {
                        id           => $job->id,
                        name         => $job->name,
                        deps         => $job->dependencies,
                        result       => $job->result,
                        result_stats => $stats->{$job->id},
                        state        => $job->state,
                        clone        => $job->clone_id,
                        finished     => $job->t_finished ? $job->t_finished->datetime() . 'Z' : undef,
                    });
            }
            return \@data;
        },
    );
}

1;
# vim: set sw=4 et:
