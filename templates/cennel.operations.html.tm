<!DOCTYPE html>
<html t:params=$operations>
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title>Cennel recent operations</title>

<h1>Cennel recent operations</h1>

<table>
  <tbody>
    <t:for as=$op x=$operations>
      <tr>
        <th><a pl:href="'/cennel/logs/' . $op->{operation}->{id}"><code><t:text value="$op->{operation}->{id}"></code></a>
        <td>
          <p><a pl:href="'/repos?repository_url=' . percent_encode_c $op->{repository}->{url}"><t:text value="$op->{repository}->{url}"></a>
          <p><a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $op->{repository}->{url}) . '&sha=' . percent_encode_c $op->{repository}->{sha}"><t:text value="substr $op->{repository}->{sha}, 0, 10"></a>
          (<a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $op->{repository}->{url}) . '&sha=' . percent_encode_c $op->{repository}->{branch}"><t:text value="$op->{repository}->{branch}"></a>)
        <td>
          <p>@<t:text value="$op->{role}->{name}">
          <p><t:text value="$op->{task}->{name}">
        <td>
          <code><t:text value="$op->{operation}->{status}"></code>
          (<t:text value="
            {
              1 => 'Initial',
              2 => 'Started',
              3 => 'Failed',
              4 => 'Succeeded',
              5 => 'Precondition failed',
              6 => 'Skipped',
            }->{$op->{operation}->{status}} || $op->{operation}->{status}
          ">)
        <td>
          <p><t:text value="
            $op->{operation}->{start_timestamp}
                ? scalar gmtime $op->{operation}->{start_timestamp}
                : ''
          ">
          <p><t:text value="
            $op->{operation}->{end_timestamp}
                ? scalar gmtime $op->{operation}->{end_timestamp}
                : ''
          ">
    </t:for>
</table>
