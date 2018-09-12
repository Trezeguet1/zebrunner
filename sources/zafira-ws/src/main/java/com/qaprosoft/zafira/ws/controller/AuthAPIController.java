/*******************************************************************************
 * Copyright 2013-2018 QaProSoft (http://www.qaprosoft.com).
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *******************************************************************************/
package com.qaprosoft.zafira.ws.controller;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletResponse;
import javax.validation.Valid;

import com.qaprosoft.zafira.models.db.Invitation;
import com.qaprosoft.zafira.models.db.Tenancy;
import com.qaprosoft.zafira.models.dto.auth.*;
import com.qaprosoft.zafira.models.dto.aws.FileUploadType;
import com.qaprosoft.zafira.services.exceptions.*;
import com.qaprosoft.zafira.services.services.application.InvitationService;
import com.qaprosoft.zafira.services.services.application.jmx.AmazonService;
import org.apache.commons.lang3.StringUtils;
import org.dozer.Mapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import com.qaprosoft.zafira.dbaccess.utils.TenancyContext;
import com.qaprosoft.zafira.models.db.Group;
import com.qaprosoft.zafira.models.db.User;
import com.qaprosoft.zafira.models.dto.user.UserType;
import com.qaprosoft.zafira.services.services.application.UserService;
import com.qaprosoft.zafira.services.services.auth.JWTService;
import com.qaprosoft.zafira.ws.swagger.annotations.ResponseStatusDetails;

import io.swagger.annotations.Api;
import io.swagger.annotations.ApiImplicitParam;
import io.swagger.annotations.ApiImplicitParams;
import io.swagger.annotations.ApiOperation;

@Controller
@Api(value = "Auth API")
@CrossOrigin
@RequestMapping("api/auth")
public class AuthAPIController extends AbstractController {

	@Autowired
	private JWTService jwtService;

	@Autowired
	private AmazonService amazonService;

	@Autowired
	private UserService userService;

	@Autowired
	private InvitationService invitationService;

	@Autowired
	private AuthenticationManager authenticationManager;

	@Autowired
	private Mapper mapper;

	@Value("${zafira.admin.username}")
	private String adminUsername;

	@ResponseStatusDetails
	@ApiOperation(value = "Get current tenant", nickname = "getTenant", code = 200, httpMethod = "GET", response = String.class)
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "tenant", method = RequestMethod.GET, produces = MediaType.APPLICATION_JSON_VALUE)
	public @ResponseBody TenantType getTenant() {
		return new TenantType(TenancyContext.getTenantName());
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Generates auth token", nickname = "login", code = 200, httpMethod = "POST", response = AuthTokenType.class)
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "login", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
	public @ResponseBody AuthTokenType login(@Valid @RequestBody CredentialsType credentials, HttpServletResponse response)
			throws BadCredentialsException {
		AuthTokenType authToken = null;
		try {
			Authentication authentication = this.authenticationManager.authenticate(
					new UsernamePasswordAuthenticationToken(credentials.getUsername(), credentials.getPassword()));

			SecurityContextHolder.getContext().setAuthentication(authentication);

			User user = userService.getUserByUsername(credentials.getUsername());

			final String tenant = user.getRoles().contains(Group.Role.ROLE_SUPERADMIN) ? Tenancy.getManagementSchema() : TenancyContext.getTenantName();

			authToken = new AuthTokenType("Bearer", jwtService.generateAuthToken(user, tenant),
					jwtService.generateRefreshToken(user, tenant), jwtService.getExpiration(), tenant);

			userService.updateLastLoginDate(user.getId());
		} catch (Exception e) {
			throw new BadCredentialsException(e.getMessage());
		}
		amazonService.getPolicyCookies().forEach((key, value) -> response.addCookie(new Cookie(key, value)));
		return authToken;
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Registration", nickname = "register", code = 200, httpMethod = "POST")
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "register", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
	public void register(@Valid @RequestBody UserType userType) throws BadCredentialsException, ServiceException {
		List<Group.Role> roles = new ArrayList<>();
		roles.add(Group.Role.ROLE_USER);
		userType.setRoles(roles);
		userService.createOrUpdateUser(mapper.map(userType, User.class));
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Sign up", nickname = "signup", code = 200, httpMethod = "POST")
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "signup", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
	public void signup(@RequestHeader(value = "Token", required = true) String token, @Valid @RequestBody UserType userType) throws BadCredentialsException, ServiceException {
		Invitation invitation = invitationService.getInvitationByToken(token);
		if(invitation == null || invitation.isExpired()) {
			throw new ForbiddenOperationException();
		}
		invitationService.deleteInvitation(invitation.getId());
		List<Group.Role> roles = new ArrayList<>();
		roles.add(Group.Role.ROLE_USER);
		userType.setRoles(roles);
		userService.createOrUpdateUser(mapper.map(userType, User.class));
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Refreshes auth token", nickname = "refreshToken", code = 200, httpMethod = "POST", response = AuthTokenType.class)
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "refresh", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
	public @ResponseBody AuthTokenType refresh(@RequestBody @Valid RefreshTokenType refreshToken, HttpServletResponse response)
			throws BadCredentialsException, ForbiddenOperationException {
		AuthTokenType authToken = null;
		try {
			User jwtUser = jwtService.parseRefreshToken(refreshToken.getRefreshToken());

			User user = userService.getUserById(jwtUser.getId());
			if (user == null) {
				throw new UserNotFoundException();
			}

			if (!TenancyContext.getTenantName().equals(jwtUser.getTenant())) {
				throw new InvalidCredentialsException("Invalid tenant");
			}

			// TODO: Do not verify password for demo user as far as it breaks demo JWT token
			if (!StringUtils.equals(adminUsername, user.getUsername())
					&& !StringUtils.equals(user.getPassword(), jwtUser.getPassword())) {
				throw new InvalidCredentialsException();
			}

			final String tenant = TenancyContext.getTenantName();

			authToken = new AuthTokenType("Bearer", jwtService.generateAuthToken(user, tenant),
					jwtService.generateRefreshToken(user, tenant), jwtService.getExpiration(),
					TenancyContext.getTenantName());

			userService.updateLastLoginDate(user.getId());
		} catch (Exception e) {
			throw new ForbiddenOperationException(e);
		}
		amazonService.getPolicyCookies().forEach((key, value) -> response.addCookie(new Cookie(key, value)));
		return authToken;
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Invite user", nickname = "inviteUser", code = 200, httpMethod = "POST")
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "invite", method = RequestMethod.POST)
	public void inviteUser(@RequestBody @Valid InvitationType... invitations) throws ServiceException {
		invitationService.createInvitations(Arrays.stream(invitations).map(invitationType -> mapper.map(invitationType, Invitation.class)).toArray(Invitation[]::new));
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Get invitation", nickname = "getInvitation", code = 200, httpMethod = "GET", response = InvitationType.class)
	@ResponseStatus(HttpStatus.OK)
	@RequestMapping(value = "invite", method = RequestMethod.GET, produces = MediaType.APPLICATION_JSON_VALUE)
	public @ResponseBody InvitationType getInvitation(@RequestParam(value = "token", required = true) String token) throws ServiceException {
		Invitation invitation = invitationService.getInvitationByToken(token);
		if(invitation == null || invitation.isExpired()) {
			throw new ForbiddenOperationException();
		}
		return mapper.map(invitation, InvitationType.class);
	}

	@ResponseStatusDetails
	@ApiOperation(value = "Generates access token", nickname = "accessToken", code = 200, httpMethod = "GET", response = AuthTokenType.class)
	@ResponseStatus(HttpStatus.OK)
	@ApiImplicitParams({ @ApiImplicitParam(name = "Authorization", paramType = "header") })
	@RequestMapping(value = "access", method = RequestMethod.GET, produces = MediaType.APPLICATION_JSON_VALUE)
	public @ResponseBody AccessTokenType accessToken() throws ServiceException {
		String token = jwtService.generateAccessToken(userService.getNotNullUserById(getPrincipalId()),
				TenancyContext.getTenantName());
		return new AccessTokenType(token);
	}
}
