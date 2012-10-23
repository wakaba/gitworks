<!DOCTYPE html>
<html t:params=$operation>
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title t:parse>Cennel operation log - <t:text value="$operation->{operation}->{id}"></title>

<h1>Cennel operation log - <code><t:text value="$operation->{operation}->{id}"></code></h1>

<dl>
  <dt>Operation ID
  <dd><a pl:href="'/cennel/logs/' . $operation->{operation}->{id}"><code><t:text value="$operation->{operation}->{id}"></code></a>

  <dt>Repository
  <dd><a pl:href="'/repos?repository_url=' . percent_encode_c $operation->{repository}->{url}"><t:text value="$operation->{repository}->{url}"></a>
  <dd><a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $operation->{repository}->{url}) . '&sha=' . percent_encode_c $operation->{repository}->{sha}"><t:text value="substr $operation->{repository}->{sha}, 0, 10"></a>
  (<a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $operation->{repository}->{url}) . '&sha=' . percent_encode_c $operation->{repository}->{branch}"><t:text value="$operation->{repository}->{branch}"></a>)

  <dt>Role
  <dd>@<t:text value="$operation->{role}->{name}">

  <dt>Task
  <dd><t:text value="$operation->{task}->{name}">

  <dt>Status
  <dd><code><t:text value="$operation->{operation}->{status}"></code>
  (<t:text value="
    {
      1 => 'Initial',
      2 => 'Started',
      3 => 'Failed',
      4 => 'Succeeded',
      5 => 'Precondition failed',
      6 => 'Skipped',
    }->{$operation->{operation}->{status}} || $operation->{operation}->{status}
  ">)

  <dt>Start
  <dd><t:text value="
      $operation->{operation}->{start_timestamp}
          ? scalar gmtime $operation->{operation}->{start_timestamp}
          : ''
  ">

  <dt>End
  <dd><t:text value="
      $operation->{operation}->{end_timestamp}
          ? scalar gmtime $operation->{operation}->{end_timestamp}
          : ''
  ">
</dl>

<nav>
  <ul>
    <li><a href=#global-log>Log</a>
    <t:for as=$unit x="[values %{$operation->{units}}]">
      <li><a pl:href="'unit-' . $unit->{id}"><t:text value="$unit->{host}->{name}"></a>
    </t:for>
  </ul>
</nav>

<section id=global-log>
  <h1>Log</h1>
  
  <pre><t:text value="$operation->{operation}->{data}"></pre>
</section>

<t:for as=$unit x="[values %{$operation->{units}}]">
  <article pl:id="'unit-' . $unit->{id}">
    <dl>
      <dt>Operation unit ID
      <dd><a pl:href="'#' . $unit->{id}"><code><t:text value="$unit->{id}"></code></a>

      <dt>Host
      <dd><code><t:text value="$unit->{host}->{name}"></code>

      <dt>Status
      <dd><code><t:text value="$unit->{status}"></code>
      (<t:text value="
        {
          1 => 'Initial',
          2 => 'Started',
          3 => 'Failed',
          4 => 'Succeeded',
          5 => 'Precondition failed',
          6 => 'Skipped',
        }->{$unit->{status}} || $unit->{status}
      ">)

      <dt>Scheduled
      <dd><t:text value="
          $unit->{scheduled_timestamp}
              ? scalar gmtime $unit->{scheduled_timestamp}
              : ''
      ">

      <dt>Start
      <dd><t:text value="
          $unit->{start_timestamp}
              ? scalar gmtime $unit->{start_timestamp}
              : ''
      ">

      <dt>End
      <dd><t:text value="
          $unit->{end_timestamp}
              ? scalar gmtime $unit->{end_timestamp}
              : ''
      ">
    </dl>
  </article>
</t:for>
