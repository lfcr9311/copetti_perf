<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="OUTPUT_FILE">
		<html>
			<head>
				<style type="text/css">td,th {font-family: courier}</style>
			</head>
			<body>
				<!-- INTERFACE VERSION, SECURITY CODE, SPEC VERSIONS -->
				<table border="1">
					<tr>
						<th width="220" align="left" >INTERFACE_VERSION</th>
						<td width="40" align="center">=</td>
						<td width="*" align="left" ><xsl:value-of select="interface_version"/></td>
					</tr>
					<tr>
						<th width="220" align="left" >SECURITY_CODE</th>
						<td width="40" align="center">=</td>
						<td width="*" align="left" >"<xsl:value-of select="security_code"/>"</td>
					</tr>
					<xsl:if test="takeoff_spec_version != ''">
						<tr>
							<th width="220" align="left" >TAKEOFF_SPEC_VERSION</th>
							<td width="40" align="center">=</td>
							<td width="*" align="left" ><xsl:value-of select="takeoff_spec_version"/></td>
						</tr>
					</xsl:if>
					<xsl:if test="landing_spec_version != ''">
						<tr>
							<th width="220" align="left" >LANDING_SPEC_VERSION</th>
							<td width="40" align="center">=</td>
							<td width="*" align="left" ><xsl:value-of select="landing_spec_version"/></td>
						</tr>
					</xsl:if>
				</table>
				<br />
				<!-- COMMON BLOCK ARRAYS/ELEMENTS -->
				<!-- Loop through each block -->
				<xsl:for-each select="block">
					<table border="1">
						<tr><th colspan="100%" align="left"><xsl:value-of select="@type"/><xsl:text></xsl:text><xsl:value-of select="@id"/></th></tr>
						<!-- Loop through each case -->
						<xsl:for-each select="case">
							<tr><th colspan="100%" align="left">CASE <xsl:value-of select="@id"/></th></tr>
							<!-- Loop through each case child -->
							<xsl:for-each select="child::*">
								<xsl:choose>
									<!-- If child is an array -->
									<xsl:when test="self::array">
										<tr><th colspan="100%" align="left"><xsl:value-of select="@name"/><xsl:text> ----------------------------------------------------------------------------------------------</xsl:text></th></tr>
										<xsl:for-each select="item[position() mod 5 = 1]/value">
											<xsl:choose>
												<xsl:when test="../unit = 'CHARACTER'">
													<xsl:apply-templates select=". | ../following-sibling::item[position() &lt;5]/value"/>
												</xsl:when>
												<xsl:otherwise>
													<tr>
														<xsl:apply-templates select=". | ../following-sibling::item[position() &lt;5]/value"/>
													</tr>
												</xsl:otherwise>
											</xsl:choose>
										</xsl:for-each>
									</xsl:when>
									<!-- If child is an element -->
									<xsl:when test="self::element">
										<tr><th colspan="100%" align="left"><xsl:value-of select="@name"/><xsl:text> ----------------------------------------------------------------------------------------------</xsl:text></th></tr>
										<tr><td colspan="100%" align="left"><xsl:value-of select="value"/></td></tr>
									</xsl:when>
								</xsl:choose>
							</xsl:for-each>
							<tr><td colspan="100%"><br /></td></tr>
						</xsl:for-each>
					</table>
					<br />
				</xsl:for-each>
			</body>
		</html>
	</xsl:template>
	<xsl:template match="value">
		<xsl:choose>
			<xsl:when test="../unit = 'CHARACTER'">
			<tr>
				<td colspan="100%">
					<xsl:apply-templates/>
				</td>
			</tr>
			</xsl:when>
			<xsl:otherwise>
				<td width="200">
					<xsl:apply-templates/>
				</td>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>